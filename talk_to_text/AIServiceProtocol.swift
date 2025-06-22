import Foundation

// MARK: - AI Provider Enums

enum AIProvider: String, CaseIterable, Identifiable {
    case gemini = "gemini"
    case openai = "openai"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .gemini:
            return "Google Gemini"
        case .openai:
            return "OpenAI ChatGPT"
        }
    }
    
    var availableModels: [AIModel] {
        switch self {
        case .gemini:
            return [
                .gemini2_5FlashLite,
                .gemini2_0FlashExp,
                .geminiPro
            ]
        case .openai:
            return [
                .gpt4o,
                .gpt4oMini,
                .gpt35Turbo
            ]
        }
    }
}

enum AIModel: String, CaseIterable, Identifiable {
    // Gemini Models
    case gemini2_5FlashLite = "gemini-2.5-flash-lite-exp"
    case gemini2_0FlashExp = "gemini-2.0-flash-exp"
    case geminiPro = "gemini-pro"
    
    // OpenAI Models
    case gpt4o = "gpt-4o"
    case gpt4oMini = "gpt-4o-mini"
    case gpt35Turbo = "gpt-3.5-turbo"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .gemini2_5FlashLite:
            return "Gemini 2.5 Flash Lite (Latest)"
        case .gemini2_0FlashExp:
            return "Gemini 2.0 Flash (Experimental)"
        case .geminiPro:
            return "Gemini Pro (Legacy)"
        case .gpt4o:
            return "GPT-4o (Latest)"
        case .gpt4oMini:
            return "GPT-4o Mini (Fast)"
        case .gpt35Turbo:
            return "GPT-3.5 Turbo (Budget)"
        }
    }
    
    var provider: AIProvider {
        switch self {
        case .gemini2_5FlashLite, .gemini2_0FlashExp, .geminiPro:
            return .gemini
        case .gpt4o, .gpt4oMini, .gpt35Turbo:
            return .openai
        }
    }
    
    var isRecommended: Bool {
        switch self {
        case .gemini2_5FlashLite, .gpt4o:
            return true
        default:
            return false
        }
    }
}

// MARK: - AI Service Protocol

protocol AITextProcessor {
    var provider: AIProvider { get }
    var model: AIModel { get }
    var isConfigured: Bool { get }
    
    func processText(_ text: String) async throws -> String
    func testConnection() async throws -> Bool
    func configure(apiKey: String, model: AIModel)
}

// MARK: - Common Errors

enum AIServiceError: LocalizedError {
    case missingAPIKey(AIProvider)
    case emptyText
    case invalidURL
    case invalidResponse
    case httpError(Int, String?)
    case networkError(Error)
    case jsonError(Error)
    case modelNotSupported(AIModel, AIProvider)
    case rateLimitExceeded
    case quotaExceeded
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "\(provider.displayName) API key is not set. Please configure it in Settings."
        case .emptyText:
            return "Input text is empty."
        case .invalidURL:
            return "Invalid API URL."
        case .invalidResponse:
            return "Invalid response from server."
        case .httpError(let code, let message):
            if let message = message {
                return "HTTP error \(code): \(message)"
            } else {
                return "HTTP error: \(code). Please check your API key and try again."
            }
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .jsonError(let error):
            return "JSON processing error: \(error.localizedDescription)"
        case .modelNotSupported(let model, let provider):
            return "Model \(model.displayName) is not supported by \(provider.displayName)"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please wait and try again."
        case .quotaExceeded:
            return "API quota exceeded. Please check your billing settings."
        case .authenticationFailed:
            return "Authentication failed. Please check your API key."
        }
    }
}