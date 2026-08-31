import Foundation
import AVFoundation
import CoreGraphics
import Combine

class MicLevelMonitor: ObservableObject {
    static let shared = MicLevelMonitor()
    
    @Published var levels: [CGFloat] = Array(repeating: 0.1, count: 13)
    
    private var audioEngine: AVAudioEngine?
    private var isMonitoring = false
    private let engineQueue = DispatchQueue(label: "com.visorpro.miclevelmonitor", qos: .userInitiated)
    private var monitoringSessionID = UUID()
    private var isCurrentlySilent = true
    private var configChangeWorkItem: DispatchWorkItem?
    private var gracefulStopWorkItem: DispatchWorkItem?
    private var lastEngineStartTime: Date = .distantPast
    
    private init() {
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.handleConfigurationChange()
        }
    }
    
    func handleDeviceSwitch() {
        engineQueue.async { [weak self] in
            guard let self = self, self.isMonitoring else { return }
            self.configChangeWorkItem?.cancel()
            self.configChangeWorkItem = nil
            let currentSessionID = self.monitoringSessionID
            if self.audioEngine != nil {
                self.audioEngine?.stop()
                self.audioEngine = nil
            }
            self.setupAndStartEngine(sessionID: currentSessionID)
        }
    }
    
    private func handleConfigurationChange() {
        if Date().timeIntervalSince(lastEngineStartTime) < 1.0 {
            return
        }
        
        engineQueue.async { [weak self] in
            guard let self = self, self.isMonitoring else { return }
            
            // Fast debounce for rapid configuration changes
            self.configChangeWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self, self.isMonitoring else { return }
                let currentSessionID = self.monitoringSessionID
                self.setupAndStartEngine(sessionID: currentSessionID)
            }
            self.configChangeWorkItem = workItem
            self.engineQueue.asyncAfter(deadline: .now() + 0.1, execute: workItem)
        }
    }
    
    func startMonitoring() {
        // Cancel any pending graceful shutdown
        gracefulStopWorkItem?.cancel()
        gracefulStopWorkItem = nil
        
        guard !isMonitoring else { return }
        isMonitoring = true
        let sessionID = UUID()
        self.monitoringSessionID = sessionID
        self.isCurrentlySilent = true
        
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
            self.setupAndStartEngine(sessionID: sessionID)
        } else {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                guard granted else {
                    DispatchQueue.main.async { self?.isMonitoring = false }
                    return
                }
                self?.setupAndStartEngine(sessionID: sessionID)
            }
        }
    }
    
    private func setupAndStartEngine(sessionID: UUID, retryCount: Int = 0) {
        engineQueue.async { [weak self] in
            guard let self = self else { return }
            
            // If stopMonitoring was called before we started or session changed
            guard self.monitoringSessionID == sessionID, self.isMonitoring else { return }
            
            if self.audioEngine == nil {
                let engine = AVAudioEngine()
                _ = engine.inputNode // Initialize the input node to prevent NSException
                engine.prepare()
                self.audioEngine = engine
            }
            
            guard let engine = self.audioEngine else { return }
            let inputNode = engine.inputNode
            
            if engine.isRunning {
                inputNode.removeTap(onBus: 0)
                engine.stop()
            } else {
                inputNode.removeTap(onBus: 0)
            }
            
            // AirPods workaround: Prepare engine first to let it negotiate the hardware format before installing the tap
            engine.prepare()
            
            var inputFormat = inputNode.inputFormat(forBus: 0)
            if inputFormat.sampleRate == 0 {
                inputFormat = inputNode.outputFormat(forBus: 0)
            }
            
            // If the hardware format is still completely broken (e.g., Bluetooth initializing), DO NOT INSTALL THE TAP!
            // Forcing a tap with 0 sample rate or 0 channels, or a mismatched hardcoded format, will crash the app with NSException.
            guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
                self.audioEngine = nil
                return
            }
            
            inputNode.installTap(onBus: 0, bufferSize: 512, format: inputFormat) { [weak self] (buffer, time) in
                self?.processBuffer(buffer: buffer)
            }
            
            do {
                if !engine.isRunning {
                    try engine.start()
                    self.lastEngineStartTime = Date()
                }
                // Final check to prevent leak if stop was called during engine startup
                if self.monitoringSessionID != sessionID || !self.isMonitoring {
                    self.audioEngine?.inputNode.removeTap(onBus: 0)
                    self.audioEngine?.stop()
                    self.audioEngine = nil
                }
            } catch {
                LogManager.shared.log("Error in MicLevelMonitor.swift: \(error)", level: "ERROR")
                // Fast retry every 100ms up to 5 times (helps instantly catch Bluetooth device readiness)
                if retryCount < 6 {
                    engine.inputNode.removeTap(onBus: 0)
                    if engine.isRunning { engine.stop() }
                    engine.reset()
                    self.audioEngine = nil
                    self.engineQueue.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        guard let self = self else { return }
                        if self.monitoringSessionID == sessionID && self.isMonitoring {
                            self.setupAndStartEngine(sessionID: sessionID, retryCount: retryCount + 1)
                        }
                    }
                }
            }
        }
    }
    
    func stopMonitoring(immediately: Bool = false) {
        gracefulStopWorkItem?.cancel()
        gracefulStopWorkItem = nil
        
        if immediately {
            performStop()
        } else {
            let workItem = DispatchWorkItem { [weak self] in
                self?.performStop()
            }
            gracefulStopWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
        }
    }
    
    private func performStop() {
        guard isMonitoring else { return }
        isMonitoring = false
        monitoringSessionID = UUID() // invalidate any pending starts
        configChangeWorkItem?.cancel()
        configChangeWorkItem = nil
        isCurrentlySilent = true
        
        engineQueue.async { [weak self] in
            guard let self = self else { return }
            self.audioEngine?.inputNode.removeTap(onBus: 0)
            if self.audioEngine?.isRunning == true {
                self.audioEngine?.stop()
            }
            self.audioEngine?.reset()
            self.audioEngine = nil // Destroy to release mic
        }
        
        DispatchQueue.main.async {
            self.levels = Array(repeating: 0.1, count: 13)
        }
    }
    
    private func processBuffer(buffer: AVAudioPCMBuffer) {
        let frames = buffer.frameLength
        if frames == 0 { return }
        
        var rms: Float = 0.0
        
        if let floatData = buffer.floatChannelData?[0] {
            for i in 0..<Int(frames) {
                let sample = floatData[i]
                rms += sample * sample
            }
        } else if let int16Data = buffer.int16ChannelData?[0] {
            for i in 0..<Int(frames) {
                let sample = Float(int16Data[i]) / 32768.0
                rms += sample * sample
            }
        } else if let int32Data = buffer.int32ChannelData?[0] {
            for i in 0..<Int(frames) {
                let sample = Float(int32Data[i]) / 2147483648.0
                rms += sample * sample
            }
        } else {
            return
        }
        
        rms = sqrt(rms / Float(frames))
        
        // Normalization with wider dynamic range suitable for Bluetooth headsets (AirPods) and built-in mics
        let minDb: Float = -58.0
        let db = 20 * log10(max(rms, 0.000001))
        let normalizedLevel = max(0.0, min(1.0, CGFloat((db - minDb) / (-minDb))))
        
        if normalizedLevel < 0.04 {
            // Absolute stillness when there is no significant noise
            if !self.isCurrentlySilent {
                self.isCurrentlySilent = true
                let silentLevels: [CGFloat] = Array(repeating: 0.1, count: 13)
                DispatchQueue.main.async {
                    self.levels = silentLevels
                }
            }
        } else {
            self.isCurrentlySilent = false
            // Generate a smooth symmetric wave look with dynamic response
            let boostedLevel = min(1.0, pow(normalizedLevel, 0.85) * 1.6)
            
            let newLevels: [CGFloat] = [
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
            
            DispatchQueue.main.async {
                self.levels = newLevels
            }
        }
    }
}
