import Foundation
import Speech
import AVFoundation
import os.log

protocol SpeechRecognizerDelegate: AnyObject {
    func speechRecognizer(_ recognizer: SpeechRecognizer, didStartRecording: Bool)
    func speechRecognizer(_ recognizer: SpeechRecognizer, didRecognizeText text: String)
    func speechRecognizer(_ recognizer: SpeechRecognizer, didFailWithError error: Error)
}

class SpeechRecognizer: ObservableObject {
    weak var delegate: SpeechRecognizerDelegate?
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published var isRecording = false
    @Published var recognizedText = ""
    @Published var hasPermission = false
    
    private var audioEngineRetryCount = 0
    private let maxRetries = 3
    private var lastPartialResult = "" // Store last partial result as fallback
    
    init() {
        // Suppress console logs for known framework issues
        suppressSystemLogs()
        requestPermissions()
    }
    
    private func suppressSystemLogs() {
        // Set environment variable to reduce logging verbosity for Speech framework
        setenv("OS_ACTIVITY_MODE", "disable", 1)
        
        // Additional environment variables to suppress specific logs
        setenv("LIBDISPATCH_LOG", "OFF", 1)
        setenv("OS_ACTIVITY_DT_MODE", "NO", 1)
        
        // Suppress specific framework logs
        #if DEBUG
        // Additional logging configuration for development
        print("Speech recognition logging suppression enabled")
        #endif
    }
    
    private func requestPermissions() {
        // Check if speech recognizer is available for the locale
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            DispatchQueue.main.async {
                self.hasPermission = false
                self.delegate?.speechRecognizer(
                    self,
                    didFailWithError: SpeechRecognitionError.speechRecognizerUnavailable
                )
            }
            return
        }
        
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self?.hasPermission = true
                    self?.requestMicrophonePermission()
                case .denied, .restricted, .notDetermined:
                    self?.hasPermission = false
                    self?.delegate?.speechRecognizer(
                        self!,
                        didFailWithError: SpeechRecognitionError.permissionDenied
                    )
                @unknown default:
                    self?.hasPermission = false
                }
            }
        }
    }
    
    private func requestMicrophonePermission() {
        // On macOS, microphone permission is handled through system preferences
        // We'll check if audio input is available when we try to start recording
        print("Microphone permission will be checked during audio engine startup")
    }
    
    func startRecording() {
        guard hasPermission else {
            delegate?.speechRecognizer(self, didFailWithError: SpeechRecognitionError.permissionDenied)
            return
        }
        
        guard !isRecording else { return }
        
        audioEngineRetryCount = 0
        attemptStartRecording()
    }
    
    private func attemptStartRecording() {
        do {
            try startRecognition()
        } catch let error as SpeechRecognitionError {
            if case .audioEngineError = error, audioEngineRetryCount < maxRetries {
                audioEngineRetryCount += 1
                print("Audio engine failed, retrying... (\(audioEngineRetryCount)/\(maxRetries))")
                
                // Wait a bit before retrying
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.attemptStartRecording()
                }
            } else {
                delegate?.speechRecognizer(self, didFailWithError: error)
            }
        } catch {
            delegate?.speechRecognizer(self, didFailWithError: error)
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        // Safely stop audio engine and clean up
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // Remove tap to prevent crashes
        let inputNode = audioEngine.inputNode
        if inputNode.numberOfInputs > 0 {
            inputNode.removeTap(onBus: 0)
        }
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isRecording = false
        delegate?.speechRecognizer(self, didStartRecording: false)
    }
    
    private func startRecognition() throws {
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // Stop any existing audio engine activity and reset
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // Remove existing taps safely
        let inputNode = audioEngine.inputNode
        if inputNode.numberOfInputs > 0 {
            inputNode.removeTap(onBus: 0)
        }
        
        // Reset audio engine to clear any problematic state
        audioEngine.reset()
        
        // Check if input node is available (microphone permission)
        guard inputNode.outputFormat(forBus: 0).sampleRate > 0 else {
            throw SpeechRecognitionError.microphonePermissionDenied
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.recognitionRequestFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Avoid kAFAssistantErrorDomain Code=1101 by using server-based recognition
        // This error often occurs when local dictation is not properly configured
        if #available(macOS 13.0, *) {
            recognitionRequest.requiresOnDeviceRecognition = false
        }
        
        // Add additional request configuration for better reliability
        if #available(macOS 14.0, *) {
            recognitionRequest.addsPunctuation = true
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                let recognizedText = result.bestTranscription.formattedString
                self.recognizedText = recognizedText
                isFinal = result.isFinal
                
                // Additional debugging for transcription details
                let segments = result.bestTranscription.segments
                print("Transcription segments count: \(segments.count)")
                for (i, segment) in segments.enumerated() {
                    print("Segment \(i): '\(segment.substring)' (confidence: \(segment.confidence))")
                }
                
                if isFinal {
                    DispatchQueue.main.async {
                        let trimmedText = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
                        print("Final recognition result: '\(recognizedText)' (trimmed: '\(trimmedText)') (length: \(trimmedText.count))")
                        
                        // Use fallback if final result is empty but we had partial results
                        let textToUse: String
                        if !trimmedText.isEmpty {
                            textToUse = trimmedText
                        } else if !self.lastPartialResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            textToUse = self.lastPartialResult.trimmingCharacters(in: .whitespacesAndNewlines)
                            print("Final result empty, using last partial result: '\(textToUse)'")
                        } else {
                            textToUse = ""
                        }
                        
                        if !textToUse.isEmpty {
                            print("Sending recognized text to delegate: '\(textToUse)'")
                            self.delegate?.speechRecognizer(self, didRecognizeText: textToUse)
                        } else {
                            print("Recognition completed but no text was recognized (original: '\(recognizedText)', lastPartial: '\(self.lastPartialResult)')")
                            self.delegate?.speechRecognizer(self, didFailWithError: SpeechRecognitionError.noTextRecognized)
                        }
                        self.stopRecording()
                    }
                } else if !recognizedText.isEmpty {
                    // Store partial result as fallback
                    self.lastPartialResult = recognizedText
                    print("Partial recognition: '\(recognizedText)'")
                }
            }
            
            if let error = error {
                // Filter out common 1101 errors that don't affect functionality
                let nsError = error as NSError
                if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1101 {
                    // Log but don't stop recognition for 1101 errors
                    print("Warning: Received kAFAssistantErrorDomain 1101 error, but continuing recognition")
                    return
                }
                
                DispatchQueue.main.async {
                    self.delegate?.speechRecognizer(self, didFailWithError: error)
                    self.stopRecording()
                }
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Wrap the tap installation in a try-catch to handle permission issues
        do {
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }
        } catch {
            throw SpeechRecognitionError.microphonePermissionDenied
        }
        
        // Prepare and start audio engine with error handling
        do {
            // Give the system a moment to settle after reset
            usleep(100000) // 100ms delay
            
            audioEngine.prepare()
            
            // Another small delay before starting
            usleep(50000) // 50ms delay
            
            try audioEngine.start()
            
            print("Audio engine started successfully")
        } catch let error as NSError {
            // Clean up on failure
            if inputNode.numberOfInputs > 0 {
                inputNode.removeTap(onBus: 0)
            }
            
            // Handle specific audio errors
            if error.code == -10877 {
                // kAudioUnitErr_CannotDoInCurrentContext
                print("Audio engine error -10877: Cannot start in current context")
                throw SpeechRecognitionError.audioEngineError
            } else {
                print("Audio engine start failed with error: \(error.code) - \(error.localizedDescription)")
                throw SpeechRecognitionError.microphonePermissionDenied
            }
        }
        
        isRecording = true
        recognizedText = ""
        lastPartialResult = "" // Reset fallback text
        delegate?.speechRecognizer(self, didStartRecording: true)
        
        // Auto-stop after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            if self?.isRecording == true {
                self?.stopRecording()
            }
        }
    }
}

enum SpeechRecognitionError: LocalizedError {
    case permissionDenied
    case microphonePermissionDenied
    case recognitionRequestFailed
    case speechRecognizerUnavailable
    case dictationNotConfigured
    case audioEngineError
    case noTextRecognized
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Speech recognition permission denied. Please enable it in System Settings > Privacy & Security > Speech Recognition."
        case .microphonePermissionDenied:
            return "Microphone permission denied. Please enable it in System Settings > Privacy & Security > Microphone."
        case .recognitionRequestFailed:
            return "Failed to create recognition request."
        case .speechRecognizerUnavailable:
            return "Speech recognizer is not available for Japanese locale. Please enable Dictation in System Settings > Keyboard > Dictation and download Japanese language support."
        case .dictationNotConfigured:
            return "Dictation is not properly configured. Please go to System Settings > Keyboard > Dictation and ensure it's enabled with Japanese language support downloaded."
        case .audioEngineError:
            return "Audio engine failed to start. Please try again or restart the application."
        case .noTextRecognized:
            return "No speech was detected. Please speak clearly and try again."
        }
    }
}