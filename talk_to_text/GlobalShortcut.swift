import Foundation
import Carbon
import AppKit

protocol GlobalShortcutDelegate: AnyObject {
    func globalShortcutPressed()
}

class GlobalShortcut: ObservableObject {
    static var shared: GlobalShortcut?
    
    weak var delegate: GlobalShortcutDelegate?
    
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyID = EventHotKeyID(signature: UTGetOSTypeFromString("VTXT" as CFString), id: 1)
    private var eventHandler: EventHandlerRef?
    
    @Published var isEnabled = false
    @Published var currentModifiers: Set<ModifierKey> = [.command, .shift]
    @Published var currentKeyCode: Int = 49 // Space
    
    init() {
        GlobalShortcut.shared = self
        loadStoredShortcut()
        registerHotKey()
    }
    
    deinit {
        unregisterHotKey()
    }
    
    private func loadStoredShortcut() {
        let modifiers = UserDefaults.standard.integer(forKey: "shortcutModifiers")
        let keyCode = UserDefaults.standard.integer(forKey: "shortcutKeyCode")
        
        if modifiers != 0 {
            currentModifiers = ModifierKey.fromInt(modifiers)
        }
        
        if keyCode != 0 {
            currentKeyCode = keyCode
        }
    }
    
    func updateShortcut(modifiers: Set<ModifierKey>, keyCode: Int) {
        unregisterHotKey()
        
        currentModifiers = modifiers
        currentKeyCode = keyCode
        
        UserDefaults.standard.set(ModifierKey.toInt(modifiers), forKey: "shortcutModifiers")
        UserDefaults.standard.set(keyCode, forKey: "shortcutKeyCode")
        
        registerHotKey()
    }
    
    private func registerHotKey() {
        guard eventHandler == nil else { return }
        
        let eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return eventNotHandledErr }
                
                let globalShortcut = Unmanaged<GlobalShortcut>.fromOpaque(userData).takeUnretainedValue()
                
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                
                if status == noErr && hotKeyID.id == globalShortcut.hotKeyID.id {
                    DispatchQueue.main.async {
                        globalShortcut.delegate?.globalShortcutPressed()
                    }
                    return noErr
                }
                
                return eventNotHandledErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        
        if status != noErr {
            print("Failed to install event handler: \(status)")
            return
        }
        
        let modifierFlags = convertModifiersToCarbon(currentModifiers)
        let registerStatus = RegisterEventHotKey(
            UInt32(currentKeyCode),
            UInt32(modifierFlags),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if registerStatus == noErr {
            isEnabled = true
            print("Global shortcut registered successfully")
        } else {
            print("Failed to register global shortcut: \(registerStatus)")
            isEnabled = false
        }
    }
    
    private func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        
        isEnabled = false
    }
    
    private func convertModifiersToCarbon(_ modifiers: Set<ModifierKey>) -> Int {
        var carbonModifiers = 0
        
        for modifier in modifiers {
            switch modifier {
            case .command:
                carbonModifiers |= cmdKey
            case .option:
                carbonModifiers |= optionKey
            case .control:
                carbonModifiers |= controlKey
            case .shift:
                carbonModifiers |= shiftKey
            }
        }
        
        return carbonModifiers
    }
}

extension GlobalShortcut {
    func getCurrentShortcutString() -> String {
        var components: [String] = []
        
        if currentModifiers.contains(.command) { components.append("⌘") }
        if currentModifiers.contains(.option) { components.append("⌥") }
        if currentModifiers.contains(.control) { components.append("⌃") }
        if currentModifiers.contains(.shift) { components.append("⇧") }
        
        if let keyName = KeyCodeHelper.keyFromCode(currentKeyCode) {
            components.append(keyName)
        }
        
        return components.joined(separator: " + ")
    }
}