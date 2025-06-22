import SwiftUI
import AppKit

class MenuBarManager: ObservableObject {
    private var statusBarItem: NSStatusItem!
    private var speechRecognizer: SpeechRecognizer!
    private var globalShortcut: GlobalShortcut!
    private var textInserter: TextInserter!
    private var settingsWindowController: NSWindowController?
    
    // Track the app that was active before speech recognition
    private var previousActiveApp: NSRunningApplication?
    
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
        
        let accessibilityMenuItem = NSMenuItem(title: "Accessibility Setup", action: #selector(handleAccessibilitySetup), keyEquivalent: "")
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
        // Remember the currently active app before starting recording
        rememberCurrentActiveApp()
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
    
    @objc private func handleAccessibilitySetup() {
        // First check current permission status
        textInserter.checkAccessibilityPermission()
        
        if textInserter.hasAccessibilityPermission {
            // Permission already granted
            updateStatus("✅ Accessibility permission is already granted!")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.updateStatus("Ready")
            }
        } else {
            // Permission not granted - help user set it up
            print("\n=== Accessibility Setup Required ===")
            print("Auto-paste requires accessibility permission.")
            print("Opening System Settings for you...")
            
            // Try to open settings
            textInserter.openAccessibilitySettings()
            
            // Show helpful status message
            updateStatus("⚠️ Open System Settings → Privacy & Security → Accessibility")
            
            // Check again after some time
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.textInserter.checkAccessibilityPermission()
                if self.textInserter.hasAccessibilityPermission {
                    self.updateStatus("✅ Permission granted! Auto-paste ready")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.updateStatus("Ready")
                    }
                } else {
                    self.updateStatus("❌ Still need accessibility permission for auto-paste")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.updateStatus("Ready")
                    }
                }
            }
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - App Focus Management
    
    private func rememberCurrentActiveApp() {
        // Find the currently active app that's not our app
        let runningApps = NSWorkspace.shared.runningApplications
        let currentPID = ProcessInfo.processInfo.processIdentifier
        
        for app in runningApps {
            if app.processIdentifier != currentPID && 
               app.activationPolicy == .regular && 
               app.isActive && 
               !app.isTerminated {
                previousActiveApp = app
                print("MenuBarManager: Remembered active app: \(app.localizedName ?? "Unknown")")
                break
            }
        }
        
        if previousActiveApp == nil {
            print("MenuBarManager: No active app found to remember")
        }
    }
    
    private func restorePreviousAppFocus(completion: @escaping () -> Void) {
        print("MenuBarManager: Attempting to restore focus to previous app")
        
        // Hide our menu bar app to lose focus
        NSApp.hide(nil)
        
        // Wait a moment for our app to hide
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let targetApp = self.previousActiveApp, !targetApp.isTerminated {
                print("MenuBarManager: Restoring focus to: \(targetApp.localizedName ?? "Unknown")")
                
                // Activate the previous app with strong focus
                let success = targetApp.activate(options: [.activateIgnoringOtherApps])
                print("MenuBarManager: App activation success: \(success)")
                
                // Wait for app activation to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    print("MenuBarManager: Proceeding with text insertion")
                    completion()
                }
            } else {
                print("MenuBarManager: No previous app to restore or app terminated")
                // Still wait a bit for our app to hide
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    completion()
                }
            }
        }
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
        print("MenuBarManager received text: '\(text)' (length: \(text.count))")
        
        // Check if API key is configured
        let apiKey = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
        
        if apiKey.isEmpty {
            // No API key - use raw speech recognition text
            DispatchQueue.main.async {
                // Copy to clipboard
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
                print("Text copied to clipboard: '\(text)'")
                
                // Insert into active application
                print("Calling textInserter.insertText with: '\(text)'")
                
                // Ensure we restore focus to the original app before text insertion
                self.restorePreviousAppFocus {
                    self.textInserter.insertText(text)
                }
                
                // Small delay to allow TextInserter to complete its work and re-check permissions
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.textInserter.checkAccessibilityPermission()
                    if self.textInserter.hasAccessibilityPermission {
                        self.updateStatus("Text inserted automatically! (Set API key for AI processing)")
                    } else {
                        self.updateStatus("Text copied to clipboard! Grant accessibility permission for auto-paste")
                    }
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
                        // Ensure we restore focus to the original app before text insertion
                        self.restorePreviousAppFocus {
                            self.textInserter.insertText(processedText)
                        }
                        
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
                        
                        // Ensure we restore focus to the original app before text insertion
                        self.restorePreviousAppFocus {
                            self.textInserter.insertText(text)
                        }
                        
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
                case .noTextRecognized:
                    errorMessage = "No speech detected. Please speak clearly and try again."
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
        print("MenuBarManager: Global shortcut pressed")
        toggleRecording()
    }
}