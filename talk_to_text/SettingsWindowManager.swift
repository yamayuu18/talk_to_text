import SwiftUI
import AppKit

class SettingsWindowManager: ObservableObject {
    private var settingsWindow: NSWindow?
    private var windowDelegate: SettingsWindowDelegate?
    
    func showSettings() {
        if let existingWindow = settingsWindow {
            // 既存のウィンドウがある場合は前面に表示
            existingWindow.makeKeyAndOrderFront(nil)
            existingWindow.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // 新しい設定ウィンドウを作成
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        
        // ウィンドウの設定
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Talk to Text - 設定"
        window.contentViewController = hostingController
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.minSize = NSSize(width: 500, height: 400)
        window.maxSize = NSSize(width: 1000, height: 800)
        
        // デリゲートを強参照で保持
        let delegate = SettingsWindowDelegate { [weak self] in
            self?.settingsWindow = nil
            self?.windowDelegate = nil
        }
        
        window.delegate = delegate
        self.windowDelegate = delegate
        self.settingsWindow = window
        
        // ウィンドウを表示
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hideSettings() {
        settingsWindow?.orderOut(nil)
    }
}

// ウィンドウデリゲート
private class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    private let onWindowClosed: () -> Void
    
    init(onWindowClosed: @escaping () -> Void) {
        self.onWindowClosed = onWindowClosed
        super.init()
    }
    
    func windowWillClose(_ notification: Notification) {
        onWindowClosed()
    }
}