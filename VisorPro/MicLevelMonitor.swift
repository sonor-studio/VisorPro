import Foundation
import AVFoundation
import CoreGraphics
import Combine

class MicLevelMonitor: ObservableObject {
    static let shared = MicLevelMonitor()
    
    @Published var levels: [CGFloat] = Array(repeating: 0.1, count: 13)
    
    private let audioEngine = AVAudioEngine()
    private var isMonitoring = false
    
    private init() {}
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            guard granted else {
                print("[MicLevelMonitor] Mic access denied")
                return
            }
            
            DispatchQueue.main.async {
                self?.setupAndStartEngine()
            }
        }
    }
    
    private func setupAndStartEngine() {
        // Reset levels
        self.levels = Array(repeating: 0.1, count: 13)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let inputNode = self.audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            
            // Remove tap just in case
            inputNode.removeTap(onBus: 0)
            
            if format.channelCount == 0 {
                let backupFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)
                inputNode.installTap(onBus: 0, bufferSize: 1024, format: backupFormat) { [weak self] (buffer, time) in
                    self?.processBuffer(buffer: buffer)
                }
            } else {
                inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] (buffer, time) in
                    self?.processBuffer(buffer: buffer)
                }
            }
            
            self.audioEngine.prepare()
            do {
                try self.audioEngine.start()
                self.isMonitoring = true
            } catch {
                print("[MicLevelMonitor] Error starting audio engine: \(error)")
            }
        }
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        
        isMonitoring = false
        
        DispatchQueue.main.async {
            self.levels = Array(repeating: 0.1, count: 13)
        }
    }
    
    private func processBuffer(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frames = buffer.frameLength
        
        var rms: Float = 0.0
        for i in 0..<Int(frames) {
            let sample = channelData[i]
            rms += sample * sample
        }
        rms = sqrt(rms / Float(frames))
        
        // Normalization
        let minDb: Float = -45.0
        let db = 20 * log10(max(rms, 0.000001))
        
        let normalizedLevel = max(0.0, min(1.0, CGFloat((db - minDb) / (-minDb))))
        
        let newLevels: [CGFloat]
        
        if normalizedLevel < 0.05 {
            // Absolute stillness when there is no significant noise
            newLevels = Array(repeating: 0.1, count: 13)
        } else {
            // Generate a smooth symmetric wave look based on the master volume level
            let boostedLevel = min(1.0, normalizedLevel * 1.5)
            
            newLevels = [
                max(0.1, boostedLevel * CGFloat.random(in: 0.1...0.3)),
                max(0.1, boostedLevel * CGFloat.random(in: 0.2...0.4)),
                max(0.1, boostedLevel * CGFloat.random(in: 0.3...0.5)),
                max(0.1, boostedLevel * CGFloat.random(in: 0.5...0.7)),
                max(0.1, boostedLevel * CGFloat.random(in: 0.7...0.9)),
                max(0.1, boostedLevel * CGFloat.random(in: 0.8...1.0)),
                max(0.1, boostedLevel),
                max(0.1, boostedLevel * CGFloat.random(in: 0.8...1.0)),
                max(0.1, boostedLevel * CGFloat.random(in: 0.7...0.9)),
                max(0.1, boostedLevel * CGFloat.random(in: 0.5...0.7)),
                max(0.1, boostedLevel * CGFloat.random(in: 0.3...0.5)),
                max(0.1, boostedLevel * CGFloat.random(in: 0.2...0.4)),
                max(0.1, boostedLevel * CGFloat.random(in: 0.1...0.3))
            ]
        }
        
        DispatchQueue.main.async {
            self.levels = newLevels
        }
    }
}
