import Foundation
import AppKit
import ApplicationServices

class TextInserter: ObservableObject {
    @Published var hasAccessibilityPermission = false
    
    init() {
        checkAccessibilityPermission()
    }
    
    func checkAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions(options)
        
        print("Accessibility permission status: \(hasAccessibilityPermission ? "✅ Granted" : "❌ Denied")")
    }
    
    
    func insertText(_ text: String) {
        guard !text.isEmpty else { return }
        
        // Verify clipboard contents (should already be set by MenuBarManager)
        let pasteboard = NSPasteboard.general
        if pasteboard.string(forType: .string) != text {
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }
        
        // Check accessibility permission
        checkAccessibilityPermission()
        
        guard hasAccessibilityPermission else {
            print("TextInserter: Accessibility permission required for auto-paste")
            return
        }
        
        // Simple delay then paste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.sendPasteCommand()
        }
    }
    
    
    private func sendPasteCommand() -> Bool {
        print("TextInserter: Creating paste command events")
        
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
        
        print("TextInserter: Sending single Cmd+V command")
        
        // Send the key events with proper timing - ONLY ONCE
        keyDownEvent.post(tap: .cgSessionEventTap)
        usleep(50000) // 50ms delay between key down and up
        keyUpEvent.post(tap: .cgSessionEventTap)
        
        print("TextInserter: Cmd+V sent successfully")
        
        // Give the paste operation time to complete
        usleep(100000) // 100ms delay
        
        return true
    }
    
    
    func openAccessibilitySettings() {
        // For macOS 13+ try to open Settings directly to Accessibility section
        if #available(macOS 13.0, *) {
            let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
                return
            }
        }
        
        // Fallback: open general Security settings
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }
}