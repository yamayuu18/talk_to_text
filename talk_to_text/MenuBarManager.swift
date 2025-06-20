import SwiftUI
import AppKit

class MenuBarManager: ObservableObject {
    private var statusBarItem: NSStatusItem!
    private var speechRecognizer: SpeechRecognizer!
    private var globalShortcut: GlobalShortcut!
    private var textInserter: TextInserter!
    
    @Published var isRecording = false
    @Published var statusText = "Ready"
    
    init() {
        setupStatusBar()
        setupComponents()
    }
    
    private func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem.button {
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Voice to Text")
            button.image?.isTemplate = true
        }
        
        setupMenu()
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        let statusMenuItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let recordMenuItem = NSMenuItem(title: "Start Recording", action: #selector(toggleRecording), keyEquivalent: "")
        recordMenuItem.target = self
        menu.addItem(recordMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsMenuItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsMenuItem.target = self
        menu.addItem(settingsMenuItem)
        
        let quitMenuItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)
        
        statusBarItem.menu = menu
    }
    
    private func setupComponents() {
        speechRecognizer = SpeechRecognizer()
        globalShortcut = GlobalShortcut()
        textInserter = TextInserter()
        
        speechRecognizer.delegate = self
        globalShortcut.delegate = self
    }
    
    @objc private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        speechRecognizer.startRecording()
    }
    
    private func stopRecording() {
        speechRecognizer.stopRecording()
    }
    
    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func updateStatus(_ text: String) {
        DispatchQueue.main.async {
            self.statusText = text
            if let menu = self.statusBarItem.menu,
               let statusItem = menu.items.first {
                statusItem.title = text
            }
        }
    }
}

extension MenuBarManager: SpeechRecognizerDelegate {
    func speechRecognizer(_ recognizer: SpeechRecognizer, didStartRecording: Bool) {
        DispatchQueue.main.async {
            self.isRecording = didStartRecording
            self.updateStatus(didStartRecording ? "Recording..." : "Ready")
            
            if let button = self.statusBarItem.button {
                button.image = NSImage(systemSymbolName: didStartRecording ? "mic.fill" : "mic", 
                                     accessibilityDescription: "Voice to Text")
            }
        }
    }
    
    func speechRecognizer(_ recognizer: SpeechRecognizer, didRecognizeText text: String) {
        updateStatus("Processing...")
        
        Task {
            do {
                let processedText = try await GeminiAPI.shared.processText(text)
                
                DispatchQueue.main.async {
                    // Copy to clipboard
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(processedText, forType: .string)
                    
                    // Insert into active application
                    self.textInserter.insertText(processedText)
                    
                    self.updateStatus("Text inserted!")
                    
                    // Reset status after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.updateStatus("Ready")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.updateStatus("Error: \(error.localizedDescription)")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.updateStatus("Ready")
                    }
                }
            }
        }
    }
    
    func speechRecognizer(_ recognizer: SpeechRecognizer, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isRecording = false
            self.updateStatus("Error: \(error.localizedDescription)")
            
            if let button = self.statusBarItem.button {
                button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Voice to Text")
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.updateStatus("Ready")
            }
        }
    }
}

extension MenuBarManager: GlobalShortcutDelegate {
    func globalShortcutPressed() {
        toggleRecording()
    }
}