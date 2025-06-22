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
        
        // より詳細な権限状態をログ出力
        print("Accessibility permission status: \(hasAccessibilityPermission ? "✅ Granted" : "❌ Denied")")
        print("Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")
        print("App executable path: \(Bundle.main.executablePath ?? "Unknown")")
        
        // 権限が無い場合の詳細ガイダンス
        if !hasAccessibilityPermission {
            print("⚠️ To grant accessibility permission:")
            print("   1. Open System Settings → Privacy & Security → Accessibility")
            print("   2. Find 'Voice to Text' or 'talk_to_text' app")
            print("   3. Enable the toggle next to the app")
            print("   4. If app is not listed, click '+' and add it manually")
        }
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
        
        // Enhanced delay for better stability and multiple retry attempts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.sendPasteCommandWithRetry(text: text, retryCount: 0)
        }
    }
    
    private func sendPasteCommandWithRetry(text: String, retryCount: Int) {
        let maxRetries = 3
        let success = sendPasteCommand()
        
        if !success && retryCount < maxRetries {
            print("TextInserter: Paste attempt \(retryCount + 1) failed, retrying...")
            
            // クリップボードを再設定
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            
            // 少し待ってからリトライ
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.sendPasteCommandWithRetry(text: text, retryCount: retryCount + 1)
            }
        } else if success {
            print("TextInserter: Paste command sent successfully")
        } else {
            print("TextInserter: All paste attempts failed after \(maxRetries) retries")
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
        
        // Send the key events with improved timing for better stability
        keyDownEvent.post(tap: .cgSessionEventTap)
        usleep(100000) // 100ms delay between key down and up (increased from 50ms)
        keyUpEvent.post(tap: .cgSessionEventTap)
        
        print("TextInserter: Cmd+V sent successfully")
        
        // Give the paste operation more time to complete for better reliability
        usleep(150000) // 150ms delay (increased from 100ms)
        
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