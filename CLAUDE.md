# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build/Run/Test Commands

- Build and run: `open talk_to_text.xcodeproj` (opens in Xcode for build/run)
- CLI build: `xcodebuild -project talk_to_text.xcodeproj -scheme talk_to_text -configuration Release`
- Debug build: `xcodebuild -project talk_to_text.xcodeproj -scheme talk_to_text -configuration Debug`
- Clean build: Select Product > Clean Build Folder in Xcode

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

### Permission Requirements
The app requires several macOS permissions managed through entitlements and Info.plist:
- Microphone access (audio input)
- Speech recognition
- Accessibility (for cross-app text insertion)
- Apple Events (for AppleScript automation)
- Network client (for Gemini API calls)

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