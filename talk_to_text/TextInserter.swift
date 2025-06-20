import Foundation
import AppKit
import ApplicationServices

class TextInserter: ObservableObject {
    @Published var hasAccessibilityPermission = false
    
    init() {
        checkAccessibilityPermission()
    }
    
    func checkAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }
    
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    func insertText(_ text: String) {
        print("TextInserter.insertText called with: '\(text)' (length: \(text.count))")
        guard !text.isEmpty else { 
            print("TextInserter: text is empty, returning")
            return 
        }
        
        // Always copy to clipboard first
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        print("TextInserter: Text set to clipboard")
        
        guard hasAccessibilityPermission else {
            print("Accessibility permission not granted - text copied to clipboard only")
            // Show system prompt to grant permission
            requestAccessibilityPermission()
            return
        }
        
        // Method 1: Try paste operation (most reliable)
        if insertTextUsingPaste() {
            return
        }
        
        // Method 2: Try using CGEvent to simulate typing
        if insertTextUsingCGEvent(text) {
            return
        }
        
        // Method 3: Fallback to AppleScript
        insertTextUsingAppleScript(text)
    }
    
    private func insertTextUsingPaste() -> Bool {
        print("TextInserter: Attempting to paste using Cmd+V")
        
        // Send Cmd+V to paste the text we already put in clipboard
        guard let keyDownEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: 9, // V key
            keyDown: true
        ), let keyUpEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: 9, // V key
            keyDown: false
        ) else {
            print("TextInserter: Failed to create key events for paste")
            return false
        }
        
        // Set Command modifier
        keyDownEvent.flags = .maskCommand
        keyUpEvent.flags = .maskCommand
        
        keyDownEvent.post(tap: .cghidEventTap)
        usleep(10000) // 10ms delay
        keyUpEvent.post(tap: .cghidEventTap)
        
        print("TextInserter: Cmd+V sent successfully")
        return true
    }
    
    private func insertTextUsingCGEvent(_ text: String) -> Bool {
        // First, get the current focused element
        guard getFocusedApplication() != nil else {
            return false
        }
        
        // Convert text to individual characters and send as key events
        for character in text {
            if !sendCharacter(character) {
                return false
            }
        }
        
        return true
    }
    
    private func getFocusedApplication() -> AXUIElement? {
        var focusedApp: AXUIElement?
        
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedAppValue: CFTypeRef?
        
        let result = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedApplicationAttribute as CFString,
            &focusedAppValue
        )
        
        if result == .success, let appElement = focusedAppValue {
            focusedApp = (appElement as! AXUIElement)
        }
        
        return focusedApp
    }
    
    private func sendCharacter(_ character: Character) -> Bool {
        let string = String(character)
        let utf16 = Array(string.utf16)
        
        for codeUnit in utf16 {
            guard let keyDownEvent = CGEvent(
                keyboardEventSource: nil,
                virtualKey: 0,
                keyDown: true
            ), let keyUpEvent = CGEvent(
                keyboardEventSource: nil,
                virtualKey: 0,
                keyDown: false
            ) else {
                return false
            }
            
            keyDownEvent.keyboardSetUnicodeString(stringLength: 1, unicodeString: [codeUnit])
            keyUpEvent.keyboardSetUnicodeString(stringLength: 1, unicodeString: [codeUnit])
            
            keyDownEvent.post(tap: .cghidEventTap)
            keyUpEvent.post(tap: .cghidEventTap)
            
            // Small delay between characters
            usleep(1000) // 1ms
        }
        
        return true
    }
    
    private func insertTextUsingAppleScript(_ text: String) {
        let escapedText = text.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "System Events"
            keystroke "\(escapedText)"
        end tell
        """
        
        DispatchQueue.global(qos: .userInitiated).async {
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
                
                if let error = error {
                    print("AppleScript error: \(error)")
                }
            }
        }
    }
    
    func insertTextAtCursor(_ text: String) {
        // Alternative method using pasteboard and paste command
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)
        
        // Temporarily put our text in clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Send Cmd+V to paste
        simulateKeyPress(keyCode: 9, modifiers: [.command]) // V key with Command
        
        // Restore previous clipboard contents after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            pasteboard.clearContents()
            if let previousContents = previousContents {
                pasteboard.setString(previousContents, forType: .string)
            }
        }
    }
    
    private func simulateKeyPress(keyCode: UInt16, modifiers: Set<ModifierKey>) {
        var carbonModifiers: UInt32 = 0
        
        for modifier in modifiers {
            switch modifier {
            case .command:
                carbonModifiers |= UInt32(CGEventFlags.maskCommand.rawValue)
            case .option:
                carbonModifiers |= UInt32(CGEventFlags.maskAlternate.rawValue)
            case .control:
                carbonModifiers |= UInt32(CGEventFlags.maskControl.rawValue)
            case .shift:
                carbonModifiers |= UInt32(CGEventFlags.maskShift.rawValue)
            }
        }
        
        guard let keyDownEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: keyCode,
            keyDown: true
        ), let keyUpEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: keyCode,
            keyDown: false
        ) else {
            return
        }
        
        keyDownEvent.flags = CGEventFlags(rawValue: UInt64(carbonModifiers))
        keyUpEvent.flags = CGEventFlags(rawValue: UInt64(carbonModifiers))
        
        keyDownEvent.post(tap: .cghidEventTap)
        keyUpEvent.post(tap: .cghidEventTap)
    }
    
    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

// Extension for better error handling
extension TextInserter {
    enum TextInsertionError: LocalizedError {
        case accessibilityPermissionDenied
        case focusedElementNotFound
        case insertionFailed
        
        var errorDescription: String? {
            switch self {
            case .accessibilityPermissionDenied:
                return "Accessibility permission is required to insert text into other applications."
            case .focusedElementNotFound:
                return "Could not find the focused text field."
            case .insertionFailed:
                return "Failed to insert text."
            }
        }
    }
}