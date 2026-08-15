import Foundation
import AVFoundation
import CoreGraphics
import Combine

class MicLevelMonitor: ObservableObject {
    static let shared = MicLevelMonitor()
    
    @Published var levels: [CGFloat] = Array(repeating: 0.1, count: 13)
    
    private var audioEngine = AVAudioEngine()
    private var isMonitoring = false
    private let engineQueue = DispatchQueue(label: "com.visorpro.miclevelmonitor", qos: .userInitiated)
    private var monitoringSessionID = UUID()
    
    private init() {
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] _ in
            guard let self = self, self.isMonitoring else { return }
            self.stopMonitoring()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.startMonitoring()
            }
        }
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        let sessionID = UUID()
        self.monitoringSessionID = sessionID
        
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            guard granted else {
                print("[MicLevelMonitor] Mic access denied")
                DispatchQueue.main.async { self?.isMonitoring = false }
                return
            }
            
            self?.setupAndStartEngine(sessionID: sessionID)
        }
    }
    
    private func setupAndStartEngine(sessionID: UUID) {
        DispatchQueue.main.async {
            self.levels = Array(repeating: 0.1, count: 13)
        }
        
        engineQueue.async { [weak self] in
            guard let self = self else { return }
            
            // If stopMonitoring was called before we started
            guard self.monitoringSessionID == sessionID, self.isMonitoring else { return }
            
            // Recreate engine to prevent stale device format exceptions
            if self.audioEngine.isRunning {
                self.audioEngine.stop()
            }
            self.audioEngine = AVAudioEngine()
            
            let inputNode = self.audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            
            inputNode.removeTap(onBus: 0)
            
            // Use nil for format to let the engine automatically use the correct node format,
            // or fallback to a standard format if the node's format is totally invalid.
            if format.channelCount == 0 || format.sampleRate == 0 {
                let backupFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)
                inputNode.installTap(onBus: 0, bufferSize: 1024, format: backupFormat) { [weak self] (buffer, time) in
                    self?.processBuffer(buffer: buffer)
                }
            } else {
                inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] (buffer, time) in
                    self?.processBuffer(buffer: buffer)
                }
            }
            
            self.audioEngine.prepare()
            do {
                try self.audioEngine.start()
                // Final check to prevent leak if stop was called during engine startup
                if self.monitoringSessionID != sessionID || !self.isMonitoring {
                    self.audioEngine.stop()
                }
            } catch {
                print("[MicLevelMonitor] Error starting audio engine: \(error)")
                DispatchQueue.main.async {
                    if self.monitoringSessionID == sessionID {
                        self.isMonitoring = false
                    }
                }
            }
        }
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        monitoringSessionID = UUID() // invalidate any pending starts
        
        engineQueue.async { [weak self] in
            guard let self = self else { return }
            if self.audioEngine.isRunning {
                self.audioEngine.inputNode.removeTap(onBus: 0)
                self.audioEngine.stop()
            }
        }
        
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
