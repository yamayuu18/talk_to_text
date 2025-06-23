import Foundation
import AVFoundation
import AudioToolbox

enum FeedbackType {
    case recordStart      // 録音開始音
    case recordStop       // 録音停止音
    case success          // 成功音
    case error            // エラー音
    case processing       // 処理中音
}

class AudioFeedbackManager: ObservableObject {
    static let shared = AudioFeedbackManager()
    
    @Published var isSoundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isSoundEnabled, forKey: "audioFeedbackEnabled")
        }
    }
    
    @Published var feedbackVolume: Float {
        didSet {
            UserDefaults.standard.set(feedbackVolume, forKey: "audioFeedbackVolume")
        }
    }
    
    private var audioPlayers: [FeedbackType: AVAudioPlayer] = [:]
    
    private init() {
        // ユーザー設定を読み込み（デフォルトは有効）
        self.isSoundEnabled = UserDefaults.standard.object(forKey: "audioFeedbackEnabled") as? Bool ?? true
        self.feedbackVolume = UserDefaults.standard.object(forKey: "audioFeedbackVolume") as? Float ?? 0.7
        
        loadAudioFiles()
    }
    
    private func loadAudioFiles() {
        // カスタム音声を作成（プログラム的に生成）
        createCustomSounds()
    }
    
    private func createCustomSounds() {
        // 短いビープ音を生成（録音開始）
        createBeepSound(for: .recordStart, frequency: 800, duration: 0.1)
        
        // 録音停止音（2音階）
        createDoubleBeepSound(for: .recordStop, frequency1: 600, frequency2: 400, duration: 0.15)
        
        // 成功音（上昇音階）
        createSuccessSound(for: .success)
        
        // エラー音（下降音階）
        createErrorSound(for: .error)
        
        // 処理中音（ソフトなビープ）
        createBeepSound(for: .processing, frequency: 440, duration: 0.2)
    }
    
    private func createBeepSound(for type: FeedbackType, frequency: Double, duration: Double) {
        let sampleRate = 44100.0
        let samples = Int(sampleRate * duration)
        var audioData = [Int16]()
        
        for i in 0..<samples {
            let time = Double(i) / sampleRate
            let amplitude = sin(2.0 * Double.pi * frequency * time) * 0.3
            let sample = Int16(amplitude * Double(Int16.max))
            audioData.append(sample)
        }
        
        createAudioPlayer(for: type, with: audioData, sampleRate: Float(sampleRate))
    }
    
    private func createDoubleBeepSound(for type: FeedbackType, frequency1: Double, frequency2: Double, duration: Double) {
        let sampleRate = 44100.0
        let samples = Int(sampleRate * duration)
        var audioData = [Int16]()
        
        let halfSamples = samples / 2
        
        // 最初の音
        for i in 0..<halfSamples {
            let time = Double(i) / sampleRate
            let amplitude = sin(2.0 * Double.pi * frequency1 * time) * 0.3
            let sample = Int16(amplitude * Double(Int16.max))
            audioData.append(sample)
        }
        
        // 2番目の音
        for i in halfSamples..<samples {
            let time = Double(i - halfSamples) / sampleRate
            let amplitude = sin(2.0 * Double.pi * frequency2 * time) * 0.3
            let sample = Int16(amplitude * Double(Int16.max))
            audioData.append(sample)
        }
        
        createAudioPlayer(for: type, with: audioData, sampleRate: Float(sampleRate))
    }
    
    private func createSuccessSound(for type: FeedbackType) {
        let sampleRate = 44100.0
        let totalDuration = 0.4
        let samples = Int(sampleRate * totalDuration)
        var audioData = [Int16]()
        
        // 成功音：C-E-G (ド-ミ-ソ) のコード
        let frequencies = [261.63, 329.63, 392.00] // C4, E4, G4
        let noteDuration = totalDuration / Double(frequencies.count)
        
        for (index, frequency) in frequencies.enumerated() {
            let noteStart = Int(Double(index) * noteDuration * sampleRate)
            let noteEnd = Int(Double(index + 1) * noteDuration * sampleRate)
            
            for i in noteStart..<min(noteEnd, samples) {
                let time = Double(i - noteStart) / sampleRate
                let envelope = exp(-time * 3.0) // フェードアウト
                let amplitude = sin(2.0 * Double.pi * frequency * time) * 0.2 * envelope
                let sample = Int16(amplitude * Double(Int16.max))
                audioData.append(sample)
            }
        }
        
        createAudioPlayer(for: type, with: audioData, sampleRate: Float(sampleRate))
    }
    
    private func createErrorSound(for type: FeedbackType) {
        let sampleRate = 44100.0
        let totalDuration = 0.3
        let samples = Int(sampleRate * totalDuration)
        var audioData = [Int16]()
        
        // エラー音：下降する不協和音
        let frequencies = [400.0, 300.0, 200.0]
        let noteDuration = totalDuration / Double(frequencies.count)
        
        for (index, frequency) in frequencies.enumerated() {
            let noteStart = Int(Double(index) * noteDuration * sampleRate)
            let noteEnd = Int(Double(index + 1) * noteDuration * sampleRate)
            
            for i in noteStart..<min(noteEnd, samples) {
                let time = Double(i - noteStart) / sampleRate
                let amplitude = sin(2.0 * Double.pi * frequency * time) * 0.3
                let sample = Int16(amplitude * Double(Int16.max))
                audioData.append(sample)
            }
        }
        
        createAudioPlayer(for: type, with: audioData, sampleRate: Float(sampleRate))
    }
    
    private func createAudioPlayer(for type: FeedbackType, with audioData: [Int16], sampleRate: Float) {
        // WAVヘッダーを作成してAVAudioPlayerで再生可能にする
        let wavData = createWAVData(from: audioData, sampleRate: sampleRate)
        
        do {
            let player = try AVAudioPlayer(data: wavData)
            player.volume = feedbackVolume
            player.prepareToPlay()
            audioPlayers[type] = player
        } catch {
            print("AudioFeedbackManager: Failed to create audio player for \(type): \(error)")
            // フォールバックとしてシステム音声を使用
            print("AudioFeedbackManager: Using system sound as fallback")
        }
    }
    
    private func createWAVData(from audioData: [Int16], sampleRate: Float) -> Data {
        var data = Data()
        
        // WAVファイルヘッダー
        let audioDataSize = audioData.count * MemoryLayout<Int16>.size
        let fileSize = 36 + audioDataSize
        
        // RIFF Header
        data.append("RIFF".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Data($0) })
        data.append("WAVE".data(using: .ascii)!)
        
        // Format Subchunk
        data.append("fmt ".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) }) // Subchunk size
        data.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) }) // Audio format (PCM)
        data.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) }) // Number of channels
        data.append(withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) }) // Sample rate
        data.append(withUnsafeBytes(of: UInt32(sampleRate * 2).littleEndian) { Data($0) }) // Byte rate
        data.append(withUnsafeBytes(of: UInt16(2).littleEndian) { Data($0) }) // Block align
        data.append(withUnsafeBytes(of: UInt16(16).littleEndian) { Data($0) }) // Bits per sample
        
        // Data Subchunk
        data.append("data".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: UInt32(audioDataSize).littleEndian) { Data($0) })
        
        // Audio data
        for sample in audioData {
            data.append(withUnsafeBytes(of: sample.littleEndian) { Data($0) })
        }
        
        return data
    }
    
    func playFeedback(_ type: FeedbackType) {
        guard isSoundEnabled else { return }
        
        print("AudioFeedbackManager: Playing feedback: \(type)")
        
        // カスタム音声を試す
        if let player = audioPlayers[type] {
            player.volume = feedbackVolume
            if player.play() {
                return // 成功した場合はここで終了
            }
        }
        
        // カスタム音声が失敗した場合、システム音声を使用
        print("AudioFeedbackManager: Custom audio failed, using system sound")
        playSystemFeedback(type)
    }
    
    // システム音声のフォールバック（カスタム音声が利用できない場合）
    func playSystemFeedback(_ type: FeedbackType) {
        guard isSoundEnabled else { return }
        
        let systemSoundID: SystemSoundID
        switch type {
        case .recordStart:
            systemSoundID = 1103  // 録音開始音
        case .recordStop:
            systemSoundID = 1104  // 録音停止音
        case .success:
            systemSoundID = 1051  // 受信音
        case .error:
            systemSoundID = 1053  // エラー音
        case .processing:
            systemSoundID = 1105  // テキストトーン
        }
        
        AudioServicesPlaySystemSound(systemSoundID)
    }
    
    // 設定リセット
    func resetToDefaults() {
        isSoundEnabled = true
        feedbackVolume = 0.7
    }
}