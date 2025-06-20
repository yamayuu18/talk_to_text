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
        // and entitlements. No runtime request needed like on iOS.
    }
    
    func startRecording() {
        guard hasPermission else {
            delegate?.speechRecognizer(self, didFailWithError: SpeechRecognitionError.permissionDenied)
            return
        }
        
        guard !isRecording else { return }
        
        do {
            try startRecognition()
        } catch {
            delegate?.speechRecognizer(self, didFailWithError: error)
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioEngine.stop()
        recognitionRequest?.endAudio()
        
        isRecording = false
        delegate?.speechRecognizer(self, didStartRecording: false)
    }
    
    private func startRecognition() throws {
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // On macOS, AVAudioSession is not available. Audio setup is handled automatically.
        
        let inputNode = audioEngine.inputNode
        
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
                
                if isFinal {
                    DispatchQueue.main.async {
                        self.delegate?.speechRecognizer(self, didRecognizeText: recognizedText)
                        self.stopRecording()
                    }
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
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        isRecording = true
        recognizedText = ""
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
        }
    }
}