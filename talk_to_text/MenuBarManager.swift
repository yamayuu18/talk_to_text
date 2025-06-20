import SwiftUI
import AppKit

class MenuBarManager: ObservableObject {
    private var statusBarItem: NSStatusItem!
    private var speechRecognizer: SpeechRecognizer!
    private var globalShortcut: GlobalShortcut!
    private var textInserter: TextInserter!
    private var settingsWindowController: NSWindowController?
    
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
        
        let accessibilityMenuItem = NSMenuItem(title: "Grant Accessibility Permission", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        accessibilityMenuItem.target = self
        menu.addItem(accessibilityMenuItem)
        
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
        // Create or show settings window using NSWindowController
        DispatchQueue.main.async { [weak self] in
            if let settingsWindowController = self?.settingsWindowController {
                // Window already exists, just bring it to front
                settingsWindowController.window?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            } else {
                // Create new settings window
                let settingsView = SettingsView()
                let hostingController = NSHostingController(rootView: settingsView)
                
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
                    styleMask: [.titled, .closable, .miniaturizable, .resizable],
                    backing: .buffered,
                    defer: false
                )
                
                window.title = "Settings"
                window.contentViewController = hostingController
                window.isReleasedWhenClosed = false
                window.level = .normal
                window.minSize = NSSize(width: 500, height: 400)
                window.maxSize = NSSize(width: 900, height: 700)
                window.setFrame(NSRect(x: 0, y: 0, width: 600, height: 500), display: false)
                window.center()
                
                let windowController = NSWindowController(window: window)
                self?.settingsWindowController = windowController
                
                windowController.showWindow(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    @objc private func openAccessibilitySettings() {
        textInserter.openAccessibilitySettings()
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
        // Check if API key is configured
        let apiKey = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
        
        if apiKey.isEmpty {
            // No API key - use raw speech recognition text
            DispatchQueue.main.async {
                // Copy to clipboard
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
                
                // Insert into active application
                self.textInserter.insertText(text)
                
                // Check if accessibility permission is granted for better status message
                if self.textInserter.hasAccessibilityPermission {
                    self.updateStatus("Raw text inserted! (Set API key for AI processing)")
                } else {
                    self.updateStatus("Text copied to clipboard! Grant accessibility permission to auto-paste")
                }
                
                // Reset status after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.updateStatus("Ready")
                }
            }
        } else {
            // API key available - process with Gemini
            updateStatus("Processing with AI...")
            
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
                        
                        // Check if accessibility permission is granted for better status message
                        if self.textInserter.hasAccessibilityPermission {
                            self.updateStatus("AI-processed text inserted!")
                        } else {
                            self.updateStatus("AI text copied to clipboard! Grant accessibility permission to auto-paste")
                        }
                        
                        // Reset status after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self.updateStatus("Ready")
                        }
                    }
                } catch {
                    // Fallback to raw text if API processing fails
                    DispatchQueue.main.async {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(text, forType: .string)
                        
                        self.textInserter.insertText(text)
                        
                        self.updateStatus("API error - used raw text: \(error.localizedDescription)")
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            self.updateStatus("Ready")
                        }
                    }
                }
            }
        }
    }
    
    func speechRecognizer(_ recognizer: SpeechRecognizer, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isRecording = false
            
            // Provide specific error messages based on error type
            var errorMessage = "Error: \(error.localizedDescription)"
            
            if let speechError = error as? SpeechRecognitionError {
                switch speechError {
                case .microphonePermissionDenied:
                    errorMessage = "Microphone access denied. Please grant permission in System Settings."
                case .permissionDenied:
                    errorMessage = "Speech recognition permission denied. Please enable in System Settings."
                case .speechRecognizerUnavailable:
                    errorMessage = "Speech recognition unavailable. Please enable Dictation in System Settings."
                case .audioEngineError:
                    errorMessage = "Audio engine failed. Please try again or check microphone settings."
                default:
                    errorMessage = "Speech recognition error: \(speechError.localizedDescription)"
                }
            }
            
            self.updateStatus(errorMessage)
            
            if let button = self.statusBarItem.button {
                button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Voice to Text")
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
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