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
3. **Processing**: Selected AI service (Gemini 2.5 Flash Lite, ChatGPT, etc.) processes/corrects the recognized text
4. **Output**: Text is inserted into active application + copied to clipboard

### Key Components & Relationships

**TalkToTextApp.swift** - SwiftUI app entry point with NSApplicationDelegate
- Initializes MenuBarManager in AppDelegate.applicationDidFinishLaunching
- Sets app as accessory (no dock icon) using NSApp.setActivationPolicy(.accessory)

**MenuBarManager.swift** - Central coordinator implementing multiple delegate protocols
- Manages NSStatusItem (menu bar icon) and menu interactions
- Coordinates between SpeechRecognizer, GlobalShortcut, TextInserter, and AIServiceManager
- Implements SpeechRecognizerDelegate and GlobalShortcutDelegate
- Handles the complete workflow: recording → recognition → AI processing → text insertion

**SpeechRecognizer.swift** - Apple Speech Recognition wrapper
- Uses SFSpeechRecognizer with Japanese locale ("ja-JP")
- Manages AVAudioEngine for audio capture
- Auto-stops recording after 30 seconds
- Delegates recognition results back to MenuBarManager

**AI Service Layer** - Multi-provider AI text processing system
- **AIServiceManager.swift**: Central coordinator for all AI providers with unified interface
- **AIServiceProtocol.swift**: Protocol definitions (AITextProcessor) and common types (AIProvider, AIModel, AIServiceError)
- **GeminiAPIService.swift**: Google Gemini API client supporting 2.5 Flash Lite, 2.0 Flash Exp, and Pro models
- **OpenAIAPIService.swift**: OpenAI ChatGPT API client supporting GPT-4o, GPT-4o Mini, and GPT-3.5 Turbo
- **GeminiAPI.swift**: Legacy Gemini implementation (maintained for compatibility)

**Key Features**:
- Automatic fallback between AI services
- Per-provider configuration and usage statistics
- Model-specific parameter optimization (temperature, tokens, etc.)
- Unified error handling across all providers

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
- Three-tab interface: AI Models, API Keys, and Shortcuts
- Real-time AI provider and model selection
- Multi-provider API key management with individual testing
- Real-time shortcut customization with visual feedback

### Permission Requirements & Configuration Files
The app requires several macOS permissions managed through entitlements and Info.plist:

**talk_to_text.entitlements:**
- `com.apple.security.device.microphone` - Audio input for speech recognition
- `com.apple.security.device.audio-input` - Additional audio access
- `com.apple.security.automation.apple-events` - AppleScript keystroke automation
- `com.apple.security.network.client` - AI API HTTP requests (Gemini, OpenAI)

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
- Singleton pattern for service managers (AIServiceManager.shared, GlobalShortcut.shared)

## Important Implementation Details

### Speech Recognition Locale
The app is hardcoded for Japanese speech recognition (`Locale(identifier: "ja-JP")`). When adding support for other languages, update SpeechRecognizer initialization and AI service prompts accordingly.

**IMPORTANT**: This application is specifically designed for Japanese language processing. Always respond in Japanese when working on this codebase and ensure all AI prompts and text processing maintain Japanese language context.

### Global Shortcut Registration
GlobalShortcut uses Carbon framework EventHotKeyRef which requires manual memory management. The class properly handles registration/unregistration in init/deinit to prevent memory leaks.

### Text Insertion Strategies
TextInserter implements multiple fallback mechanisms:
1. CGEvent-based character simulation (primary)
2. AppleScript keystroke automation (fallback)
3. Clipboard-based paste operation (emergency fallback)

### API Key Security
AI service API keys (Gemini, OpenAI) are stored in UserDefaults (not Keychain). For production apps, consider migrating to Keychain for enhanced security.

### Error Handling Patterns
Each major component defines custom error enums (e.g., AIServiceError, SpeechRecognitionError) with localized descriptions for user-facing error messages. The AI service layer uses a unified AIServiceError enum for consistent error handling across providers.

## Development Setup & Configuration

### Required Setup Steps
1. **AI API Keys**: 
   - **Gemini API Key**: Obtain from [Google AI Studio](https://aistudio.google.com/)
   - **OpenAI API Key**: Obtain from [OpenAI Platform](https://platform.openai.com/)
   - Configure either or both in app settings
2. **macOS Permissions**: App requires microphone, speech recognition, accessibility, and Apple Events permissions
3. **Minimum macOS**: 13.0+ (defined in deployment target)
4. **Code Signing**: Uses automatic signing - no developer team configuration required for local development

### Key UserDefaults Keys
- `"geminiAPIKey"`: Stores Gemini API key
- `"openaiAPIKey"`: Stores OpenAI API key
- `"selectedAIProvider"`: Current AI provider selection (gemini/openai)
- `"selectedAIModel"`: Current AI model selection
- `"shortcutModifiers"`: Global shortcut modifier keys (as integer bitmask)
- `"shortcutKeyCode"`: Global shortcut key code

### Testing the Application
- **Manual Testing**: Build and run through Xcode, trigger shortcut (⌘+⇧+Space) to test recording workflow
- **AI API Testing**: Use Settings panel "Test Current API Key" button to validate selected AI service
- **Provider Switching**: Test switching between Gemini and OpenAI providers in Settings
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

## AI Service Architecture

### Adding New AI Providers
To add a new AI provider, follow this pattern:

1. **Extend AIProvider enum** in `AIServiceProtocol.swift`:
   ```swift
   case newProvider = "newprovider"
   ```

2. **Add new models** to AIModel enum:
   ```swift
   case newProviderModel = "model-name"
   ```

3. **Create new service class** implementing `AITextProcessor`:
   ```swift
   class NewProviderAPIService: AITextProcessor {
       let provider = AIProvider.newProvider
       // Implement required methods
   }
   ```

4. **Update AIServiceManager** to handle the new provider in switch statements

5. **Add UI support** in SettingsView.swift for the new provider's API key

### AI Service Configuration
Each AI service handles its own:
- Model-specific parameters (temperature, tokens, etc.)
- Usage statistics tracking
- Error handling and retry logic
- Configuration persistence

The AIServiceManager provides:
- Unified interface for all providers
- Automatic fallback handling
- Provider/model selection persistence
- Cross-provider configuration synchronization

### Prompt Engineering
Each AI service uses Japanese-optimized prompts for text correction:
- Filler word removal ("えーと", "あのー", etc.)
- Natural speech-to-text conversion
- Punctuation and formatting correction
- Meaning preservation (critical requirement)

**Language Requirements**:
- All AI prompts must be in Japanese
- All user-facing messages must be in Japanese
- All code comments should be in Japanese when working on this project
- Always maintain Japanese language context in all development work