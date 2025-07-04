import Foundation

class GeminiAPI {
    static let shared = GeminiAPI()
    
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent"
    private let session = URLSession.shared
    
    private init() {}
    
    private var apiKey: String {
        return UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
    }
    
    func processText(_ text: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw GeminiAPIError.missingAPIKey
        }
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GeminiAPIError.emptyText
        }
        
        let request = try buildRequest(for: text)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GeminiAPIError.invalidResponse
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw GeminiAPIError.httpError(httpResponse.statusCode)
            }
            
            return try parseResponse(data)
            
        } catch let error as GeminiAPIError {
            throw error
        } catch {
            throw GeminiAPIError.networkError(error)
        }
    }
    
    private func buildRequest(for text: String) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            throw GeminiAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let prompt = createPrompt(for: text)
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": prompt
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.2,
                "topK": 32,
                "topP": 0.9,
                "maxOutputTokens": 4096
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw GeminiAPIError.jsonEncodingError(error)
        }
        
        return request
    }
    
    private func createPrompt(for text: String) -> String {
        return """
        あなたは高品質な文章校正AIです。以下の音声認識で得られたテキストを、自然で読みやすい日本語に校正してください。

        校正の際は以下の点に注意してください：
        1. 誤字脱字の修正
        2. "えーと"、"あのー"、"まあ"のようなフィラーワードの除去
        3. 話し言葉から書き言葉への自然な変換
        4. 適切な句読点の挿入
        5. 文章構造の整理と自然な流れの確保
        6. 敬語や丁寧語の統一
        7. 重複表現の削除

        重要な制約：
        - 元のテキストの意味や意図は決して変更しないでください
        - 校正後のテキストのみを出力してください（説明や前置きは不要）
        - 空の入力の場合は何も出力しないでください

        音声認識テキスト：
        \(text)
        """
    }
    
    private func parseResponse(_ data: Data) throws -> String {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw GeminiAPIError.invalidJSON
            }
            
            guard let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let firstPart = parts.first,
                  let text = firstPart["text"] as? String else {
                throw GeminiAPIError.invalidResponseFormat
            }
            
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
            
        } catch let error as GeminiAPIError {
            throw error
        } catch {
            throw GeminiAPIError.jsonDecodingError(error)
        }
    }
    
    func testAPIKey() async throws -> Bool {
        let testText = "これは、えーと、テストです。"
        
        do {
            let result = try await processText(testText)
            // Verify that the response is not only non-empty but also processed correctly
            let trimmedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmedResult.isEmpty && trimmedResult != testText
        } catch {
            throw error
        }
    }
}

enum GeminiAPIError: LocalizedError {
    case missingAPIKey
    case emptyText
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case networkError(Error)
    case jsonEncodingError(Error)
    case jsonDecodingError(Error)
    case invalidJSON
    case invalidResponseFormat
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini API key is not set. Please configure it in Settings."
        case .emptyText:
            return "Input text is empty."
        case .invalidURL:
            return "Invalid API URL."
        case .invalidResponse:
            return "Invalid response from server."
        case .httpError(let code):
            return "HTTP error: \(code). Please check your API key and try again."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .jsonEncodingError(let error):
            return "JSON encoding error: \(error.localizedDescription)"
        case .jsonDecodingError(let error):
            return "JSON decoding error: \(error.localizedDescription)"
        case .invalidJSON:
            return "Invalid JSON response."
        case .invalidResponseFormat:
            return "Unexpected response format from Gemini API."
        }
    }
}

extension GeminiAPI {
    func getUsageStatistics() -> [String: Any] {
        let defaults = UserDefaults.standard
        return [
            "totalRequests": defaults.integer(forKey: "gemini_total_requests"),
            "totalTokens": defaults.integer(forKey: "gemini_total_tokens"),
            "lastUsed": defaults.object(forKey: "gemini_last_used") as? Date ?? Date()
        ]
    }
    
    private func updateUsageStatistics() {
        let defaults = UserDefaults.standard
        let currentRequests = defaults.integer(forKey: "gemini_total_requests")
        defaults.set(currentRequests + 1, forKey: "gemini_total_requests")
        defaults.set(Date(), forKey: "gemini_last_used")
    }
    
    // MARK: - Enhanced API Processing
    
    func processTextWithFallback(_ text: String) async -> (result: String, isProcessed: Bool) {
        guard !apiKey.isEmpty else {
            return (text, false)
        }
        
        do {
            let processedText = try await processText(text)
            updateUsageStatistics()
            return (processedText, true)
        } catch {
            print("Gemini API processing failed: \(error.localizedDescription)")
            // Return original text as fallback
            return (text, false)
        }
    }
}