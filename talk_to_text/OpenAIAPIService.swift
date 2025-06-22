import Foundation

class OpenAIAPIService: AITextProcessor {
    let provider = AIProvider.openai
    private(set) var model: AIModel = .gpt4o
    private let session = URLSession.shared
    private var apiKey: String = ""
    
    var isConfigured: Bool {
        return !apiKey.isEmpty
    }
    
    init() {
        loadConfiguration()
    }
    
    private func loadConfiguration() {
        apiKey = UserDefaults.standard.string(forKey: "openaiAPIKey") ?? ""
        if let modelString = UserDefaults.standard.string(forKey: "openaiModel"),
           let savedModel = AIModel(rawValue: modelString),
           savedModel.provider == .openai {
            model = savedModel
        }
    }
    
    func configure(apiKey: String, model: AIModel) {
        guard model.provider == .openai else {
            print("Warning: Attempted to configure OpenAI service with non-OpenAI model: \(model.displayName)")
            return
        }
        
        self.apiKey = apiKey
        self.model = model
        
        UserDefaults.standard.set(apiKey, forKey: "openaiAPIKey")
        UserDefaults.standard.set(model.rawValue, forKey: "openaiModel")
    }
    
    func processText(_ text: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw AIServiceError.missingAPIKey(.openai)
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
                
                // Handle specific OpenAI error codes
                switch httpResponse.statusCode {
                case 401:
                    throw AIServiceError.authenticationFailed
                case 429:
                    throw AIServiceError.rateLimitExceeded
                case 402:
                    throw AIServiceError.quotaExceeded
                default:
                    throw AIServiceError.httpError(httpResponse.statusCode, errorMessage)
                }
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
        let baseURL = "https://api.openai.com/v1/chat/completions"
        guard let url = URL(string: baseURL) else {
            throw AIServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let prompt = createPrompt(for: text)
        
        let requestBody: [String: Any] = [
            "model": model.rawValue,
            "messages": [
                [
                    "role": "system",
                    "content": "あなたは音声認識テキストの校正を専門とする高品質なAIアシスタントです。与えられたテキストを自然で読みやすい日本語に校正してください。"
                ],
                [
                    "role": "user", 
                    "content": prompt
                ]
            ],
            "temperature": temperatureConfig(for: model),
            "max_tokens": maxTokensConfig(for: model),
            "top_p": 0.9
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw AIServiceError.jsonError(error)
        }
        
        return request
    }
    
    private func temperatureConfig(for model: AIModel) -> Double {
        switch model {
        case .gpt4o:
            return 0.1  // Highest precision for latest model
        case .gpt4oMini:
            return 0.15
        case .gpt35Turbo:
            return 0.2
        default:
            return 0.15
        }
    }
    
    private func maxTokensConfig(for model: AIModel) -> Int {
        switch model {
        case .gpt4o:
            return 4096
        case .gpt4oMini:
            return 2048
        case .gpt35Turbo:
            return 1024
        default:
            return 2048
        }
    }
    
    private func createPrompt(for text: String) -> String {
        return """
        以下の音声認識で得られたテキストを、自然で読みやすい日本語に校正してください。

        校正の際は以下の点に注意してください：
        1. 誤字脱字の修正
        2. "えーと"、"あのー"、"まあ"、"そのー"などのフィラーワードの除去
        3. 話し言葉から書き言葉への自然な変換
        4. 適切な句読点の挿入
        5. 文章構造の整理と自然な流れの確保
        6. 敬語や丁寧語の統一
        7. 重複表現の削除
        8. 不要な間投詞（"はい"、"うん"など）の除去
        9. 文脈に応じた自然な表現への調整

        重要な制約：
        - 元のテキストの意味や意図は決して変更しないでください
        - 校正後のテキストのみを出力してください（説明や前置きは不要）
        - 空の入力の場合は何も出力しないでください
        - 元の内容を要約せず、すべての重要な情報を保持してください
        - 自然な日本語として違和感のない表現にしてください

        音声認識テキスト：
        \(text)
        """
    }
    
    private func parseResponse(_ data: Data) throws -> String {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw AIServiceError.jsonError(NSError(domain: "OpenAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"]))
            }
            
            guard let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw AIServiceError.invalidResponse
            }
            
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
            
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
        let currentRequests = defaults.integer(forKey: "openai_total_requests")
        defaults.set(currentRequests + 1, forKey: "openai_total_requests")
        defaults.set(Date(), forKey: "openai_last_used")
    }
}

// MARK: - Usage Statistics

extension OpenAIAPIService {
    func getUsageStatistics() -> [String: Any] {
        let defaults = UserDefaults.standard
        return [
            "totalRequests": defaults.integer(forKey: "openai_total_requests"),
            "totalTokens": defaults.integer(forKey: "openai_total_tokens"),
            "lastUsed": defaults.object(forKey: "openai_last_used") as? Date ?? Date()
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
            print("OpenAI API processing failed: \(error.localizedDescription)")
            return (text, false)
        }
    }
}