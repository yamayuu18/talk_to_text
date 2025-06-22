import Foundation

class GeminiAPIService: AITextProcessor {
    let provider = AIProvider.gemini
    private(set) var model: AIModel = .gemini2_5FlashLite
    private let session = URLSession.shared
    private var apiKey: String = ""
    
    var isConfigured: Bool {
        return !apiKey.isEmpty
    }
    
    init() {
        loadConfiguration()
    }
    
    private func loadConfiguration() {
        apiKey = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
        if let modelString = UserDefaults.standard.string(forKey: "geminiModel"),
           let savedModel = AIModel(rawValue: modelString),
           savedModel.provider == .gemini {
            model = savedModel
        }
    }
    
    func configure(apiKey: String, model: AIModel) {
        guard model.provider == .gemini else {
            print("Warning: Attempted to configure Gemini service with non-Gemini model: \(model.displayName)")
            return
        }
        
        self.apiKey = apiKey
        self.model = model
        
        UserDefaults.standard.set(apiKey, forKey: "geminiAPIKey")
        UserDefaults.standard.set(model.rawValue, forKey: "geminiModel")
    }
    
    func processText(_ text: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw AIServiceError.missingAPIKey(.gemini)
        }
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIServiceError.emptyText
        }
        
        let request = try buildRequest(for: text)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                let errorMessage = try? parseErrorResponse(data)
                throw AIServiceError.httpError(httpResponse.statusCode, errorMessage)
            }
            
            let result = try parseResponse(data)
            updateUsageStatistics()
            return result
            
        } catch let error as AIServiceError {
            throw error
        } catch {
            throw AIServiceError.networkError(error)
        }
    }
    
    func testConnection() async throws -> Bool {
        let testText = "これは、えーと、テストです。"
        
        do {
            let result = try await processText(testText)
            let trimmedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmedResult.isEmpty && trimmedResult != testText
        } catch {
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func buildRequest(for text: String) throws -> URLRequest {
        let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/\(model.rawValue):generateContent"
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            throw AIServiceError.invalidURL
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
            "generationConfig": generationConfig(for: model)
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw AIServiceError.jsonError(error)
        }
        
        return request
    }
    
    private func generationConfig(for model: AIModel) -> [String: Any] {
        switch model {
        case .gemini2_5FlashLite:
            return [
                "temperature": 0.1,  // Even lower for highest precision
                "topK": 20,
                "topP": 0.8,
                "maxOutputTokens": 8192
            ]
        case .gemini2_0FlashExp:
            return [
                "temperature": 0.2,
                "topK": 32,
                "topP": 0.9,
                "maxOutputTokens": 4096
            ]
        case .geminiPro:
            return [
                "temperature": 0.3,
                "topK": 40,
                "topP": 0.95,
                "maxOutputTokens": 2048
            ]
        default:
            return [
                "temperature": 0.2,
                "topK": 32,
                "topP": 0.9,
                "maxOutputTokens": 4096
            ]
        }
    }
    
    private func createPrompt(for text: String) -> String {
        return """
        あなたは高品質な文章校正AIです。以下の音声認識で得られたテキストを、自然で読みやすい日本語に校正してください。

        校正の際は以下の点に注意してください：
        1. 誤字脱字の修正
        2. "えーと"、"あのー"、"まあ"、"そのー"のようなフィラーワードの除去
        3. 話し言葉から書き言葉への自然な変換
        4. 適切な句読点の挿入
        5. 文章構造の整理と自然な流れの確保
        6. 敬語や丁寧語の統一
        7. 重複表現の削除
        8. 不要な間投詞（"はい"、"うん"など）の除去

        重要な制約：
        - 元のテキストの意味や意図は決して変更しないでください
        - 校正後のテキストのみを出力してください（説明や前置きは不要）
        - 空の入力の場合は何も出力しないでください
        - 元の内容を要約せず、すべての重要な情報を保持してください

        音声認識テキスト：
        \(text)
        """
    }
    
    private func parseResponse(_ data: Data) throws -> String {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw AIServiceError.jsonError(NSError(domain: "GeminiAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"]))
            }
            
            guard let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let firstPart = parts.first,
                  let text = firstPart["text"] as? String else {
                throw AIServiceError.invalidResponse
            }
            
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
            
        } catch let error as AIServiceError {
            throw error
        } catch {
            throw AIServiceError.jsonError(error)
        }
    }
    
    private func parseErrorResponse(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return nil
        }
        return message
    }
    
    private func updateUsageStatistics() {
        let defaults = UserDefaults.standard
        let currentRequests = defaults.integer(forKey: "gemini_total_requests")
        defaults.set(currentRequests + 1, forKey: "gemini_total_requests")
        defaults.set(Date(), forKey: "gemini_last_used")
    }
}

// MARK: - Legacy Compatibility

extension GeminiAPIService {
    func getUsageStatistics() -> [String: Any] {
        let defaults = UserDefaults.standard
        return [
            "totalRequests": defaults.integer(forKey: "gemini_total_requests"),
            "totalTokens": defaults.integer(forKey: "gemini_total_tokens"),
            "lastUsed": defaults.object(forKey: "gemini_last_used") as? Date ?? Date()
        ]
    }
    
    func processTextWithFallback(_ text: String) async -> (result: String, isProcessed: Bool) {
        guard isConfigured else {
            return (text, false)
        }
        
        do {
            let processedText = try await processText(text)
            return (processedText, true)
        } catch {
            print("Gemini API processing failed: \(error.localizedDescription)")
            return (text, false)
        }
    }
}