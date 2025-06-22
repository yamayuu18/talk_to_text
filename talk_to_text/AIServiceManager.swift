import Foundation

class AIServiceManager: ObservableObject {
    static let shared = AIServiceManager()
    
    @Published var selectedProvider: AIProvider {
        didSet {
            saveProviderSelection()
            updateCurrentService()
        }
    }
    
    @Published var selectedModel: AIModel {
        didSet {
            saveModelSelection()
            updateCurrentService()
        }
    }
    
    private let geminiService = GeminiAPIService()
    private let openaiService = OpenAIAPIService()
    
    private var currentService: AITextProcessor {
        switch selectedProvider {
        case .gemini:
            return geminiService
        case .openai:
            return openaiService
        }
    }
    
    var isConfigured: Bool {
        return currentService.isConfigured
    }
    
    var availableModels: [AIModel] {
        return selectedProvider.availableModels
    }
    
    private init() {
        // Initialize with default values first
        self.selectedProvider = .gemini
        self.selectedModel = .gemini2_5FlashLite
        
        // Load saved preferences
        if let providerString = UserDefaults.standard.string(forKey: "selectedAIProvider"),
           let provider = AIProvider(rawValue: providerString) {
            selectedProvider = provider
        }
        
        if let modelString = UserDefaults.standard.string(forKey: "selectedAIModel"),
           let model = AIModel(rawValue: modelString),
           model.provider == selectedProvider {
            selectedModel = model
        } else {
            selectedModel = selectedProvider.availableModels.first(where: { $0.isRecommended }) ?? selectedProvider.availableModels.first!
        }
        
        updateCurrentService()
    }
    
    // MARK: - Public Methods
    
    func processText(_ text: String) async throws -> String {
        return try await currentService.processText(text)
    }
    
    func processTextWithFallback(_ text: String) async -> (result: String, isProcessed: Bool) {
        guard isConfigured else {
            return (text, false)
        }
        
        do {
            let processedText = try await processText(text)
            return (processedText, true)
        } catch {
            print("\(selectedProvider.displayName) API processing failed: \(error.localizedDescription)")
            return (text, false)
        }
    }
    
    func testConnection() async throws -> Bool {
        return try await currentService.testConnection()
    }
    
    func configure(geminiAPIKey: String?, openaiAPIKey: String?) {
        if let geminiKey = geminiAPIKey, !geminiKey.isEmpty {
            let model = selectedProvider == .gemini ? selectedModel : .gemini2_5FlashLite
            geminiService.configure(apiKey: geminiKey, model: model)
        }
        
        if let openaiKey = openaiAPIKey, !openaiKey.isEmpty {
            let model = selectedProvider == .openai ? selectedModel : .gpt4o
            openaiService.configure(apiKey: openaiKey, model: model)
        }
        
        updateCurrentService()
    }
    
    func getUsageStatistics() -> [String: Any] {
        var stats: [String: Any] = [:]
        
        let geminiStats = geminiService.getUsageStatistics()
        let openaiStats = openaiService.getUsageStatistics()
        
        stats["gemini"] = geminiStats
        stats["openai"] = openaiStats
        stats["currentProvider"] = selectedProvider.rawValue
        stats["currentModel"] = selectedModel.rawValue
        
        return stats
    }
    
    func getProviderStatus() -> [AIProvider: Bool] {
        return [
            .gemini: geminiService.isConfigured,
            .openai: openaiService.isConfigured
        ]
    }
    
    // MARK: - Private Methods
    
    private func updateCurrentService() {
        switch selectedProvider {
        case .gemini:
            if geminiService.isConfigured && geminiService.model != selectedModel {
                let apiKey = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
                if !apiKey.isEmpty {
                    geminiService.configure(apiKey: apiKey, model: selectedModel)
                }
            }
        case .openai:
            if openaiService.isConfigured && openaiService.model != selectedModel {
                let apiKey = UserDefaults.standard.string(forKey: "openaiAPIKey") ?? ""
                if !apiKey.isEmpty {
                    openaiService.configure(apiKey: apiKey, model: selectedModel)
                }
            }
        }
    }
    
    private func saveProviderSelection() {
        UserDefaults.standard.set(selectedProvider.rawValue, forKey: "selectedAIProvider")
    }
    
    private func saveModelSelection() {
        UserDefaults.standard.set(selectedModel.rawValue, forKey: "selectedAIModel")
    }
}

// MARK: - Convenience Methods

extension AIServiceManager {
    var currentProviderDisplayName: String {
        return selectedProvider.displayName
    }
    
    var currentModelDisplayName: String {
        return selectedModel.displayName
    }
    
    var isCurrentModelRecommended: Bool {
        return selectedModel.isRecommended
    }
    
    func switchToProvider(_ provider: AIProvider) {
        selectedProvider = provider
        
        // Auto-select recommended model for the new provider
        if let recommendedModel = provider.availableModels.first(where: { $0.isRecommended }) {
            selectedModel = recommendedModel
        } else if let firstModel = provider.availableModels.first {
            selectedModel = firstModel
        }
    }
    
    func switchToModel(_ model: AIModel) {
        guard model.provider == selectedProvider else {
            print("Warning: Attempted to select model \(model.displayName) for different provider")
            return
        }
        selectedModel = model
    }
}