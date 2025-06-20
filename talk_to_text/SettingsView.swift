import SwiftUI

struct SettingsView: View {
    @AppStorage("geminiAPIKey") private var geminiAPIKey: String = ""
    @AppStorage("shortcutModifiers") private var shortcutModifiers: Int = 0
    @AppStorage("shortcutKeyCode") private var shortcutKeyCode: Int = 0
    
    @State private var selectedModifiers: Set<ModifierKey> = []
    @State private var selectedKey: String = "Space"
    @State private var isWaitingForKeyPress = false
    @State private var showingAPIKeyAlert = false
    
    private let availableKeys = [
        "Space", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", 
        "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0"
    ]
    
    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            
            shortcutTab
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
        }
        .onAppear {
            loadStoredShortcut()
        }
    }
    
    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Gemini API Key")
                    .font(.headline)
                
                SecureField("Enter your Gemini API key", text: $geminiAPIKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("Get your API key from Google AI Studio")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Button("Test API Key") {
                    testAPIKey()
                }
                .disabled(geminiAPIKey.isEmpty)
                
                Spacer()
                
                Button("Clear") {
                    geminiAPIKey = ""
                }
                .disabled(geminiAPIKey.isEmpty)
            }
            
            Spacer()
        }
        .padding()
        .alert("API Key Status", isPresented: $showingAPIKeyAlert) {
            Button("OK") { }
        } message: {
            Text(geminiAPIKey.isEmpty ? "Please enter an API key" : "API key format looks valid")
        }
    }
    
    private var shortcutTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Global Shortcut")
                    .font(.headline)
                
                Text("Choose a keyboard shortcut to start/stop recording")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Modifier Keys")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(ModifierKey.allCases, id: \.self) { modifier in
                        HStack {
                            Button(action: {
                                toggleModifier(modifier)
                            }) {
                                HStack {
                                    Image(systemName: selectedModifiers.contains(modifier) ? "checkmark.square" : "square")
                                    Text(modifier.displayName)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Key")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Key", selection: $selectedKey) {
                    ForEach(availableKeys, id: \.self) { key in
                        Text(key).tag(key)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: 200, alignment: .leading)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Shortcut")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(currentShortcutString)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
            }
            
            HStack {
                Button("Apply Shortcut") {
                    applyShortcut()
                }
                .disabled(selectedModifiers.isEmpty)
                
                Spacer()
                
                Button("Reset to Default") {
                    resetToDefault()
                }
            }
            
            Spacer()
        }
        .padding()
        .onChange(of: selectedModifiers) { _ in updateStoredShortcut() }
        .onChange(of: selectedKey) { _ in updateStoredShortcut() }
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
    
    private func applyShortcut() {
        GlobalShortcut.shared?.updateShortcut(
            modifiers: selectedModifiers,
            keyCode: shortcutKeyCode
        )
    }
    
    private func resetToDefault() {
        selectedModifiers = [.command, .shift]
        selectedKey = "Space"
        updateStoredShortcut()
        applyShortcut()
    }
    
    private func testAPIKey() {
        showingAPIKeyAlert = true
    }
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