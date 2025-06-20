# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build/Run/Test Commands

- **Development**: `open talk_to_text.xcodeproj` (opens in Xcode for build/run)
- **CLI Debug Build**: `xcodebuild -project talk_to_text.xcodeproj -scheme talk_to_text -configuration Debug`
- **CLI Release Build**: `xcodebuild -project talk_to_text.xcodeproj -scheme talk_to_text -configuration Release` 
- **Clean Build**: `xcodebuild -project talk_to_text.xcodeproj -scheme talk_to_text clean`
- **Clear DerivedData**: `rm -rf ~/Library/Developer/Xcode/DerivedData/talk_to_text-*`
- **Launch Built App**: `open ~/Library/Developer/Xcode/DerivedData/talk_to_text-*/Build/Products/Debug/talk_to_text.app`

### Build Troubleshooting
- **File Reference Errors**: Clean DerivedData cache if Xcode references old file names
- **macOS API Compatibility**: This app uses macOS-specific APIs (Carbon, Accessibility) - avoid iOS frameworks like AVAudioSession
- **Settings Window Warnings**: Use proper SwiftUI Settings scene integration for menu bar apps - avoid SettingsLink warnings

## Architecture Overview

This is a native macOS menu bar application for speech-to-text conversion with AI-powered text correction. The app follows a delegate-based architecture with clear separation of concerns:

### Core Data Flow
1. **Input**: Global keyboard shortcut triggers speech recording
2. **Recognition**: Apple Speech Recognition converts audio to raw text (Japanese locale)
3. **Processing**: Gemini API processes/corrects the recognized text
4. **Output**: Text is inserted into active application + copied to clipboard

### Key Components & Relationships

**TalkToTextApp.swift** - SwiftUI app entry point with NSApplicationDelegate
- Initializes MenuBarManager in AppDelegate.applicationDidFinishLaunching
- Sets app as accessory (no dock icon) using NSApp.setActivationPolicy(.accessory)

**MenuBarManager.swift** - Central coordinator implementing multiple delegate protocols
- Manages NSStatusItem (menu bar icon) and menu interactions
- Coordinates between SpeechRecognizer, GlobalShortcut, and TextInserter
- Implements SpeechRecognizerDelegate and GlobalShortcutDelegate
- Handles the complete workflow: recording → recognition → API processing → text insertion

**SpeechRecognizer.swift** - Apple Speech Recognition wrapper
- Uses SFSpeechRecognizer with Japanese locale ("ja-JP")
- Manages AVAudioEngine for audio capture
- Auto-stops recording after 30 seconds
- Delegates recognition results back to MenuBarManager

**GeminiAPI.swift** - Google Gemini API integration (singleton)
- Handles HTTP requests to Gemini Pro model
- Stores API key in UserDefaults ("geminiAPIKey")
- Custom prompt for Japanese text correction/formatting
- Comprehensive error handling with custom GeminiAPIError enum

**GlobalShortcut.swift** - System-wide keyboard shortcut handling
- Uses Carbon framework for global hotkey registration
- Default: Command+Shift+Space (customizable via settings)
- Manages EventHotKeyRef and EventHandlerRef lifecycle
- Persists settings in UserDefaults

**TextInserter.swift** - Cross-application text insertion
- Uses macOS Accessibility API (requires user permission)
- Multiple insertion methods: CGEvent simulation + AppleScript fallback
- Implements clipboard integration as backup method

**SettingsView.swift** - SwiftUI settings interface
- Tabbed interface for API key and shortcut configuration
- Real-time shortcut customization with visual feedback
- API key validation and management

### Permission Requirements & Configuration Files
The app requires several macOS permissions managed through entitlements and Info.plist:

**talk_to_text.entitlements:**
- `com.apple.security.device.microphone` - Audio input for speech recognition
- `com.apple.security.device.audio-input` - Additional audio access
- `com.apple.security.automation.apple-events` - AppleScript keystroke automation
- `com.apple.security.network.client` - Gemini API HTTP requests

**Info.plist permission descriptions:**
- `NSMicrophoneUsageDescription` - User-facing microphone permission prompt
- `NSSpeechRecognitionUsageDescription` - Speech recognition permission prompt  
- `NSAppleEventsUsageDescription` - AppleScript automation permission prompt
- `LSUIElement: true` - Menu bar app (no dock icon)
- `LSMinimumSystemVersion: 13.0` - macOS 13.0+ requirement

**Missing Manual Permission:** Accessibility permission must be granted manually in System Settings → Privacy & Security → Accessibility

### State Management
- UserDefaults for persistent settings (API keys, shortcuts)
- @Published properties for UI state updates
- Delegate pattern for component communication
- Singleton pattern for API services (GeminiAPI, GlobalShortcut.shared)

## Important Implementation Details

### Speech Recognition Locale
The app is hardcoded for Japanese speech recognition (`Locale(identifier: "ja-JP")`). When adding support for other languages, update SpeechRecognizer initialization and Gemini API prompts accordingly.

### Global Shortcut Registration
GlobalShortcut uses Carbon framework EventHotKeyRef which requires manual memory management. The class properly handles registration/unregistration in init/deinit to prevent memory leaks.

### Text Insertion Strategies
TextInserter implements multiple fallback mechanisms:
1. CGEvent-based character simulation (primary)
2. AppleScript keystroke automation (fallback)
3. Clipboard-based paste operation (emergency fallback)

### API Key Security
Gemini API keys are stored in UserDefaults (not Keychain). For production apps, consider migrating to Keychain for enhanced security.

### Error Handling Patterns
Each major component defines custom error enums (e.g., GeminiAPIError, SpeechRecognitionError) with localized descriptions for user-facing error messages.

## Development Setup & Configuration

### Required Setup Steps
1. **Gemini API Key**: Obtain from [Google AI Studio](https://aistudio.google.com/) and configure in app settings
2. **macOS Permissions**: App requires microphone, speech recognition, accessibility, and Apple Events permissions
3. **Minimum macOS**: 13.0+ (defined in deployment target)
4. **Code Signing**: Uses automatic signing - no developer team configuration required for local development

### Key UserDefaults Keys
- `"geminiAPIKey"`: Stores Gemini API key
- `"shortcutModifiers"`: Global shortcut modifier keys (as integer bitmask)
- `"shortcutKeyCode"`: Global shortcut key code

### Testing the Application
- **Manual Testing**: Build and run through Xcode, trigger shortcut (⌘+⇧+Space) to test recording workflow
- **API Testing**: Use Settings panel "Test API Key" button to validate Gemini integration
- **Permission Testing**: Check System Settings → Privacy & Security for required permissions

### Known Warnings & Issues
- **Carbon API Deprecation**: `UTGetOSTypeFromString` warnings in GlobalShortcut.swift are expected - functionality still works on macOS 15+
- **Sendable Protocol**: MenuBarManager async closure warnings are expected - does not affect functionality
- **SwiftUI Settings**: If you see "Please use SettingsLink for opening the Settings scene" warnings, ensure proper Settings scene integration in menu bar apps

### Menu Bar App Settings Pattern
For menu bar apps, open Settings using version-specific selectors:
```swift
// In MenuBarManager.swift
if #available(macOS 14.0, *) {
    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
} else if #available(macOS 13.0, *) {
    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)  
}
```

### File Naming Consistency
All files use `talk_to_text` naming (not `VoiceToText`). When creating new files, follow this pattern:
- Project: `talk_to_text.xcodeproj`
- Bundle ID: `com.voicetotext.app` 
- Display name: "Talk to Text"