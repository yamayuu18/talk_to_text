import SwiftUI

struct SettingsView: View {
    @AppStorage("geminiAPIKey") private var geminiAPIKey: String = ""
    @AppStorage("openaiAPIKey") private var openaiAPIKey: String = ""
    @AppStorage("shortcutModifiers") private var shortcutModifiers: Int = 0
    @AppStorage("shortcutKeyCode") private var shortcutKeyCode: Int = 0
    
    @StateObject private var aiServiceManager = AIServiceManager.shared
    @StateObject private var audioFeedbackManager = AudioFeedbackManager.shared
    @State private var selectedModifiers: Set<ModifierKey> = []
    @State private var selectedKey: String = "Space"
    @State private var isWaitingForKeyPress = false
    @State private var showingAPIKeyAlert = false
    @State private var apiKeyTestResult: String?
    @State private var isTestingAPIKey = false
    
    private let availableKeys = [
        "Space", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", 
        "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0"
    ]
    
    var body: some View {
        TabView {
            aiModelsTab
                .tabItem {
                    Label("AI Models", systemImage: "brain")
                }
            
            apiKeysTab
                .tabItem {
                    Label("API Keys", systemImage: "key")
                }
            
            shortcutTab
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
            
            audioFeedbackTab
                .tabItem {
                    Label("Audio", systemImage: "speaker.2")
                }
        }
        .onAppear {
            loadStoredShortcut()
            syncAPIKeysWithManager()
        }
    }
    
    private var aiModelsTab: some View {
        Form {
            Section(header: Text("AI Provider")) {
                Picker("AI Provider", selection: $aiServiceManager.selectedProvider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.displayName)
                            .tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                
                Text("Choose your preferred AI service")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("AI Model")) {
                Picker("AI Model", selection: $aiServiceManager.selectedModel) {
                    ForEach(aiServiceManager.availableModels) { model in
                        HStack {
                            Text(model.displayName)
                            if model.isRecommended {
                                Text("(Recommended)")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                            }
                        }
                        .tag(model)
                    }
                }
                .pickerStyle(.menu)
                
                Text("Select the specific model for text processing")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("Configuration Status")) {
                HStack {
                    Image(systemName: aiServiceManager.isConfigured ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(aiServiceManager.isConfigured ? .green : .orange)
                    
                    Text(aiServiceManager.isConfigured ? 
                         "\(aiServiceManager.currentProviderDisplayName) is configured" : 
                         "\(aiServiceManager.currentProviderDisplayName) requires API key")
                }
            }
        }
    }
    
    private var apiKeysTab: some View {
        Form {
            Section(header: Text("Google Gemini")) {
                SecureField("Enter your Gemini API key", text: $geminiAPIKey)
                    .onChange(of: geminiAPIKey) { _ in
                        syncAPIKeysWithManager()
                    }
                
                Text("Get your API key from Google AI Studio")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("OpenAI")) {
                SecureField("Enter your OpenAI API key", text: $openaiAPIKey)
                    .onChange(of: openaiAPIKey) { _ in
                        syncAPIKeysWithManager()
                    }
                
                Text("Get your API key from OpenAI Platform")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("API Testing")) {
                Button(action: {
                    Task {
                        await testCurrentAPIKey()
                    }
                }) {
                    HStack {
                        if isTestingAPIKey {
                            ProgressView()
                                .controlSize(.small)
                            Text("Testing...")
                        } else {
                            Image(systemName: "checkmark.circle")
                            Text("Test Current API Key")
                        }
                    }
                }
                .disabled(!aiServiceManager.isConfigured || isTestingAPIKey)
            }
            
            Section {
                Button("Clear All API Keys") {
                    geminiAPIKey = ""
                    openaiAPIKey = ""
                    syncAPIKeysWithManager()
                }
                .foregroundColor(.red)
                .disabled(geminiAPIKey.isEmpty && openaiAPIKey.isEmpty)
            }
        }
        .alert("API Key Test Result", isPresented: .constant(apiKeyTestResult != nil)) {
            Button("OK") { 
                apiKeyTestResult = nil
            }
        } message: {
            Text(apiKeyTestResult ?? "")
        }
    }
    
    private var shortcutTab: some View {
        Form {
            Section(header: Text("Shortcut Configuration")) {
                Text("Press keys to set your recording shortcut. At least one modifier (⌘, ⌥, ⌃, ⇧) is required.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("⚠️ Avoid system shortcuts like Cmd+C, Cmd+V, Ctrl+V, Cmd+Space, etc.")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            
            Section(header: Text("Current Assignment")) {
                HStack {
                    Text("Active Shortcut")
                    Spacer()
                    Text(currentShortcutString.isEmpty ? "No shortcut set" : currentShortcutString)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                        .foregroundColor(currentShortcutString.isEmpty ? .secondary : .primary)
                }
                
                Button(action: {
                    isWaitingForKeyPress.toggle()
                }) {
                    HStack {
                        Image(systemName: isWaitingForKeyPress ? "record.circle.fill" : "record.circle")
                            .foregroundColor(isWaitingForKeyPress ? .red : .accentColor)
                        Text(isWaitingForKeyPress ? "Press keys now..." : "Record New Shortcut")
                    }
                }
                
                if isWaitingForKeyPress {
                    Text("Press your desired key combination now. Changes apply immediately.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .italic()
                }
            }
            
            Section(header: Text("Reset Options")) {
                Button("Reset to Default (⌘ + ⇧ + Space)") {
                    resetToDefault()
                }
            }
        }
        .background(ShortcutCaptureView(
            isCapturing: $isWaitingForKeyPress,
            onShortcutCaptured: { modifiers, keyCode in
                selectedModifiers = modifiers
                selectedKey = KeyCodeHelper.keyFromCode(keyCode) ?? "Space"
                updateStoredShortcut()
                // 即座にショートカットを適用
                GlobalShortcut.shared?.updateShortcut(
                    modifiers: selectedModifiers,
                    keyCode: keyCode
                )
            }
        ))
        .onChange(of: selectedModifiers) { _ in updateStoredShortcut() }
        .onChange(of: selectedKey) { _ in updateStoredShortcut() }
    }
    
    private var audioFeedbackTab: some View {
        Form {
            Section(header: Text("Audio Feedback Settings")) {
                Toggle("Enable Audio Feedback", isOn: $audioFeedbackManager.isSoundEnabled)
                    .help("Play sounds for different app states (start, stop, success, error)")
                
                if audioFeedbackManager.isSoundEnabled {
                    HStack {
                        Text("Volume")
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "speaker.1")
                                .foregroundColor(.secondary)
                            Slider(value: $audioFeedbackManager.feedbackVolume, in: 0.0...1.0, step: 0.1)
                                .frame(width: 120)
                            Image(systemName: "speaker.3")
                                .foregroundColor(.secondary)
                            Text("\(Int(audioFeedbackManager.feedbackVolume * 100))%")
                                .frame(width: 35, alignment: .trailing)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Section(header: Text("Sound Preview")) {
                Button(action: {
                    audioFeedbackManager.playFeedback(.recordStart)
                }) {
                    HStack {
                        Text("🔴")
                        Text("Recording Start Sound")
                        Spacer()
                    }
                }
                .disabled(!audioFeedbackManager.isSoundEnabled)
                
                Button(action: {
                    audioFeedbackManager.playFeedback(.recordStop)
                }) {
                    HStack {
                        Text("⏹️")
                        Text("Recording Stop Sound")
                        Spacer()
                    }
                }
                .disabled(!audioFeedbackManager.isSoundEnabled)
                
                Button(action: {
                    audioFeedbackManager.playFeedback(.processing)
                }) {
                    HStack {
                        Text("⚙️")
                        Text("Processing Sound")
                        Spacer()
                    }
                }
                .disabled(!audioFeedbackManager.isSoundEnabled)
                
                Button(action: {
                    audioFeedbackManager.playFeedback(.success)
                }) {
                    HStack {
                        Text("✅")
                        Text("Success Sound")
                        Spacer()
                    }
                }
                .disabled(!audioFeedbackManager.isSoundEnabled)
                
                Button(action: {
                    audioFeedbackManager.playFeedback(.error)
                }) {
                    HStack {
                        Text("❌")
                        Text("Error Sound")
                        Spacer()
                    }
                }
                .disabled(!audioFeedbackManager.isSoundEnabled)
            }
            
            Section(header: Text("Reset Options")) {
                Button("Reset to Default Settings") {
                    audioFeedbackManager.resetToDefaults()
                }
                .foregroundColor(.orange)
            }
        }
    }
    
    private var currentShortcutString: String {
        var components: [String] = []
        
        if selectedModifiers.contains(.command) { components.append("⌘") }
        if selectedModifiers.contains(.option) { components.append("⌥") }
        if selectedModifiers.contains(.control) { components.append("⌃") }
        if selectedModifiers.contains(.shift) { components.append("⇧") }
        
        components.append(selectedKey)
        
        return components.joined(separator: " + ")
    }
    
    private func toggleModifier(_ modifier: ModifierKey) {
        if selectedModifiers.contains(modifier) {
            selectedModifiers.remove(modifier)
        } else {
            selectedModifiers.insert(modifier)
        }
    }
    
    private func loadStoredShortcut() {
        selectedModifiers = ModifierKey.fromInt(shortcutModifiers)
        selectedKey = KeyCodeHelper.keyFromCode(shortcutKeyCode) ?? "Space"
    }
    
    private func updateStoredShortcut() {
        shortcutModifiers = ModifierKey.toInt(selectedModifiers)
        shortcutKeyCode = KeyCodeHelper.codeFromKey(selectedKey) ?? 49 // Space
    }
    
    private func resetToDefault() {
        selectedModifiers = [.command, .shift]
        selectedKey = "Space"
        updateStoredShortcut()
        // 即座にデフォルトショートカットを適用
        GlobalShortcut.shared?.updateShortcut(
            modifiers: selectedModifiers,
            keyCode: KeyCodeHelper.codeFromKey(selectedKey) ?? 49
        )
    }
    
    private func testCurrentAPIKey() async {
        guard aiServiceManager.isConfigured else {
            apiKeyTestResult = "Please configure an API key for \(aiServiceManager.currentProviderDisplayName) first"
            return
        }
        
        isTestingAPIKey = true
        apiKeyTestResult = nil
        
        do {
            let success = try await aiServiceManager.testConnection()
            if success {
                apiKeyTestResult = "✅ \(aiServiceManager.currentModelDisplayName) is working perfectly!"
            } else {
                apiKeyTestResult = "⚠️ API key seems valid but test response was empty"
            }
        } catch {
            apiKeyTestResult = "❌ \(aiServiceManager.currentProviderDisplayName) test failed: \(error.localizedDescription)"
        }
        
        isTestingAPIKey = false
    }
    
    private func syncAPIKeysWithManager() {
        aiServiceManager.configure(
            geminiAPIKey: geminiAPIKey.isEmpty ? nil : geminiAPIKey,
            openaiAPIKey: openaiAPIKey.isEmpty ? nil : openaiAPIKey
        )
    }
    
    // MARK: - Future Enhancement: Keychain Support
    // TODO: Add KeychainHelper.swift to Xcode project and implement secure API key storage
    // The KeychainHelper implementation is available but needs to be properly added to the Xcode project
    
    // MARK: - AI Service Integration
    // This settings view now integrates with the new AIServiceManager for multi-provider support
}

enum ModifierKey: CaseIterable {
    case command, option, control, shift
    
    var displayName: String {
        switch self {
        case .command: return "Command (⌘)"
        case .option: return "Option (⌥)"
        case .control: return "Control (⌃)"
        case .shift: return "Shift (⇧)"
        }
    }
    
    var carbonFlag: Int {
        switch self {
        case .command: return 256  // cmdKey
        case .option: return 2048  // optionKey
        case .control: return 4096 // controlKey
        case .shift: return 512    // shiftKey
        }
    }
    
    static func fromInt(_ value: Int) -> Set<ModifierKey> {
        var modifiers: Set<ModifierKey> = []
        if value & ModifierKey.command.carbonFlag != 0 { modifiers.insert(.command) }
        if value & ModifierKey.option.carbonFlag != 0 { modifiers.insert(.option) }
        if value & ModifierKey.control.carbonFlag != 0 { modifiers.insert(.control) }
        if value & ModifierKey.shift.carbonFlag != 0 { modifiers.insert(.shift) }
        return modifiers
    }
    
    static func toInt(_ modifiers: Set<ModifierKey>) -> Int {
        var value = 0
        for modifier in modifiers {
            value |= modifier.carbonFlag
        }
        return value
    }
}

struct KeyCodeHelper {
    private static let keyMap: [String: Int] = [
        "Space": 49, "A": 0, "B": 11, "C": 8, "D": 2, "E": 14, "F": 3, "G": 5,
        "H": 4, "I": 34, "J": 38, "K": 40, "L": 37, "M": 46, "N": 45, "O": 31,
        "P": 35, "Q": 12, "R": 15, "S": 1, "T": 17, "U": 32, "V": 9, "W": 13,
        "X": 7, "Y": 16, "Z": 6, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23,
        "6": 22, "7": 26, "8": 28, "9": 25, "0": 29
    ]
    
    private static let reverseKeyMap: [Int: String] = {
        var map: [Int: String] = [:]
        for (key, code) in keyMap {
            map[code] = key
        }
        return map
    }()
    
    static func codeFromKey(_ key: String) -> Int? {
        return keyMap[key]
    }
    
    static func keyFromCode(_ code: Int) -> String? {
        return reverseKeyMap[code]
    }
}

struct ShortcutCaptureView: NSViewRepresentable {
    @Binding var isCapturing: Bool
    let onShortcutCaptured: (Set<ModifierKey>, Int) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyCaptureView()
        view.delegate = context.coordinator
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let captureView = nsView as? KeyCaptureView {
            captureView.isCapturing = isCapturing
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, KeyCaptureDelegate {
        let parent: ShortcutCaptureView
        
        init(_ parent: ShortcutCaptureView) {
            self.parent = parent
        }
        
        func keyCaptured(modifiers: Set<ModifierKey>, keyCode: Int) {
            parent.isCapturing = false
            parent.onShortcutCaptured(modifiers, keyCode)
        }
    }
}

protocol KeyCaptureDelegate: AnyObject {
    func keyCaptured(modifiers: Set<ModifierKey>, keyCode: Int)
}

class KeyCaptureView: NSView {
    weak var delegate: KeyCaptureDelegate?
    var isCapturing = false {
        didSet {
            if isCapturing {
                self.window?.makeFirstResponder(self)
            }
        }
    }
    
    override var acceptsFirstResponder: Bool { return true }
    
    override func keyDown(with event: NSEvent) {
        guard isCapturing else {
            super.keyDown(with: event)
            return
        }
        
        // Convert NSEvent modifiers to our ModifierKey set
        var modifiers: Set<ModifierKey> = []
        let flags = event.modifierFlags
        
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        
        // Require at least one modifier for global shortcuts
        guard !modifiers.isEmpty else {
            NSSound.beep()
            return
        }
        
        let keyCode = Int(event.keyCode)
        
        // Check for system reserved shortcuts
        if isSystemReservedShortcut(modifiers: modifiers, keyCode: keyCode) {
            NSSound.beep()
            return
        }
        
        delegate?.keyCaptured(modifiers: modifiers, keyCode: keyCode)
    }
    
    override func flagsChanged(with event: NSEvent) {
        // Handle modifier-only combinations if needed
        super.flagsChanged(with: event)
    }
    
    private func isSystemReservedShortcut(modifiers: Set<ModifierKey>, keyCode: Int) -> Bool {
        // Common system shortcuts that should be avoided
        let systemShortcuts: [(Set<ModifierKey>, Int)] = [
            // Copy/Paste operations
            ([.command], 8), // Cmd+C
            ([.command], 9), // Cmd+V  
            ([.command], 7), // Cmd+X
            ([.control], 8), // Ctrl+C
            ([.control], 9), // Ctrl+V
            ([.control], 7), // Ctrl+X
            
            // Common system shortcuts
            ([.command], 1), // Cmd+S
            ([.command], 31), // Cmd+O
            ([.command], 45), // Cmd+N
            ([.command], 13), // Cmd+W
            ([.command], 12), // Cmd+Q
            ([.command], 6), // Cmd+Z
            ([.command, .shift], 6), // Cmd+Shift+Z
            
            // Spotlight and system
            ([.command], 49), // Cmd+Space
        ]
        
        for (systemModifiers, systemKeyCode) in systemShortcuts {
            if modifiers == systemModifiers && keyCode == systemKeyCode {
                return true
            }
        }
        
        return false
    }
}