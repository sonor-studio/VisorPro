import Foundation
import Cocoa
import CoreAudio
import AudioToolbox

class VolumeManager {
    static let shared = VolumeManager()
    
    private let queue = DispatchQueue(label: "com.visor.volumeQueue")
    
    private var cachedVolume: Int = 50
    private var cachedMuted: Bool = false
    private var isInitialized: Bool = false
    private var pendingTask: DispatchWorkItem?
    private var lastProgrammaticChangeTime: Date = Date.distantPast
    
    init() {
        setupAudioDeviceListeners()
    }
    
    private func setupAudioDeviceListeners() {
        // Listener na zmianę domyślnego urządzenia wyjściowego
        var defaultDeviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            guard let self = self else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let newName = self.getCurrentAudioDeviceName()
                MediaKeyManager.shared.currentAudioDeviceName = newName
                MediaKeyManager.shared.audioDevicesChanged = UUID()
            }
        }
        
        // Listener na zmianę domyślnego urządzenia wejściowego
        var defaultInputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultInputAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            guard let self = self else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let newName = self.getCurrentInputDeviceName()
                MediaKeyManager.shared.currentMicDeviceName = newName
                MediaKeyManager.shared.audioDevicesChanged = UUID()
            }
        }
        
        // Listener na zmianę listy dostępnych urządzeń (np. podłączenie słuchawek)
        var devicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesAddress,
            DispatchQueue.main
        ) { _, _ in
            DispatchQueue.main.async {
                MediaKeyManager.shared.audioDevicesChanged = UUID()
            }
        }
    }
    
    func getCurrentAudioDeviceName() -> String {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var defaultOutputDeviceIDSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        var getDefaultOutputDevicePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &getDefaultOutputDevicePropertyAddress,
            0,
            nil,
            &defaultOutputDeviceIDSize,
            &defaultOutputDeviceID
        )
        
        guard status == noErr else { return "Internal speakers" }
        
        var deviceName = "" as CFString
        var deviceNameSize = UInt32(MemoryLayout<CFString>.size)
        
        var deviceNamePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let nameStatus = AudioObjectGetPropertyData(
            defaultOutputDeviceID,
            &deviceNamePropertyAddress,
            0,
            nil,
            &deviceNameSize,
            &deviceName
        )
        
        guard nameStatus == noErr else { return "Internal speakers" }
        
        return deviceName as String
    }
    
    func getAvailableOutputDevices() -> [(id: AudioDeviceID, name: String)] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        if deviceCount == 0 { return [] }
        
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs)
        
        var outputDevices: [(id: AudioDeviceID, name: String)] = []
        
        for deviceID in deviceIDs {
            var streamConfigAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            var streamConfigSize: UInt32 = 0
            if AudioObjectGetPropertyDataSize(deviceID, &streamConfigAddress, 0, nil, &streamConfigSize) != noErr {
                continue
            }
            
            let audioBufferList = AudioBufferList.allocate(maximumBuffers: Int(streamConfigSize))
            defer { free(audioBufferList.unsafeMutablePointer) }
            
            if AudioObjectGetPropertyData(deviceID, &streamConfigAddress, 0, nil, &streamConfigSize, audioBufferList.unsafeMutablePointer) != noErr {
                continue
            }
            
            let buffers = UnsafeBufferPointer<AudioBuffer>(start: &audioBufferList.unsafeMutablePointer.pointee.mBuffers, count: Int(audioBufferList.unsafeMutablePointer.pointee.mNumberBuffers))
            var hasOutput = false
            for buffer in buffers {
                if buffer.mNumberChannels > 0 {
                    hasOutput = true
                    break
                }
            }
            
            if hasOutput {
                var nameAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyDeviceNameCFString,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                var deviceName: CFString?
                var nameSize = UInt32(MemoryLayout<CFString?>.size)
                if AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &deviceName) == noErr, let name = deviceName as String? {
                    outputDevices.append((id: deviceID, name: name))
                }
            }
        }
        
        return outputDevices
    }
    
    func getCurrentInputDeviceName() -> String {
        var defaultInputDeviceID = AudioDeviceID(0)
        var defaultInputDeviceIDSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        var getDefaultInputDevicePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &getDefaultInputDevicePropertyAddress,
            0,
            nil,
            &defaultInputDeviceIDSize,
            &defaultInputDeviceID
        )
        
        guard status == noErr else { return "Microphone" }
        
        var deviceName = "" as CFString
        var deviceNameSize = UInt32(MemoryLayout<CFString>.size)
        
        var deviceNamePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let nameStatus = AudioObjectGetPropertyData(
            defaultInputDeviceID,
            &deviceNamePropertyAddress,
            0,
            nil,
            &deviceNameSize,
            &deviceName
        )
        
        guard nameStatus == noErr else { return "Microphone" }
        return deviceName as String
    }
    
    func getAvailableInputDevices() -> [(id: AudioDeviceID, name: String)] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        if deviceCount == 0 { return [] }
        
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs)
        
        var inputDevices: [(id: AudioDeviceID, name: String)] = []
        
        for deviceID in deviceIDs {
            var streamConfigAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            var streamConfigSize: UInt32 = 0
            if AudioObjectGetPropertyDataSize(deviceID, &streamConfigAddress, 0, nil, &streamConfigSize) != noErr {
                continue
            }
            
            let audioBufferList = AudioBufferList.allocate(maximumBuffers: Int(streamConfigSize))
            defer { free(audioBufferList.unsafeMutablePointer) }
            
            if AudioObjectGetPropertyData(deviceID, &streamConfigAddress, 0, nil, &streamConfigSize, audioBufferList.unsafeMutablePointer) != noErr {
                continue
            }
            
            let buffers = UnsafeBufferPointer<AudioBuffer>(start: &audioBufferList.unsafeMutablePointer.pointee.mBuffers, count: Int(audioBufferList.unsafeMutablePointer.pointee.mNumberBuffers))
            var hasInput = false
            for buffer in buffers {
                if buffer.mNumberChannels > 0 {
                    hasInput = true
                    break
                }
            }
            
            if hasInput {
                var nameAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyDeviceNameCFString,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                var deviceName: CFString?
                var nameSize = UInt32(MemoryLayout<CFString?>.size)
                if AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &deviceName) == noErr, let name = deviceName as String? {
                    inputDevices.append((id: deviceID, name: name))
                }
            }
        }
        
        return inputDevices
    }
    
    func setInputDevice(id: AudioDeviceID) {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = id
        AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &deviceID)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            MediaKeyManager.shared.currentMicDeviceName = self.getCurrentInputDeviceName()
        }
    }
    
    func setOutputDevice(id: AudioDeviceID) {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = id
        AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &deviceID)
        
        // Aktualizacja nazwy urządzenia i głośności po przełączeniu
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            MediaKeyManager.shared.currentAudioDeviceName = self.getCurrentAudioDeviceName()
            // Odczytaj głośność nowego urządzenia
            self.fetchCurrentVolume { vol, muted in
                DispatchQueue.main.async {
                    self.cachedVolume = vol
                    self.cachedMuted = muted
                    MediaKeyManager.shared.currentVolume = vol
                    MediaKeyManager.shared.isMuted = muted
                }
            }
        }
    }
    
    private func getSystemVolume() -> (Float, Bool) {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &defaultOutputDeviceID)
        
        var volume: Float = 0.5
        var tempVolume: Float = 0.0
        var volSize = UInt32(MemoryLayout<Float>.size)
        
        // 1. First, try VirtualMainVolume - this correctly handles A2DP AirPods and complex devices
        var systemVolAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if AudioHardwareServiceGetPropertyData(defaultOutputDeviceID, &systemVolAddress, 0, nil, &volSize, &tempVolume) == noErr {
            volume = tempVolume
        } else {
            // 2. Fallback to Element 0 (Master)
            var volAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            if AudioObjectGetPropertyData(defaultOutputDeviceID, &volAddress, 0, nil, &volSize, &tempVolume) == noErr {
                volume = tempVolume
            } else {
                // 3. Fallback to Element 1 (Left) and Element 2 (Right) average
                var leftVolume: Float = -1.0
                var rightVolume: Float = -1.0
                
                volAddress.mElement = 1
                if AudioObjectGetPropertyData(defaultOutputDeviceID, &volAddress, 0, nil, &volSize, &tempVolume) == noErr {
                    leftVolume = tempVolume
                }
                
                volAddress.mElement = 2
                if AudioObjectGetPropertyData(defaultOutputDeviceID, &volAddress, 0, nil, &volSize, &tempVolume) == noErr {
                    rightVolume = tempVolume
                }
                
                if leftVolume >= 0 && rightVolume >= 0 {
                    volume = max(leftVolume, rightVolume)
                } else if leftVolume >= 0 {
                    volume = leftVolume
                } else if rightVolume >= 0 {
                    volume = rightVolume
                }
            }
        }
        
        var isMuted: UInt32 = 0
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        var status = AudioObjectGetPropertyData(defaultOutputDeviceID, &muteAddress, 0, nil, &muteSize, &isMuted)
        if status != noErr {
            muteAddress.mElement = 1
            status = AudioObjectGetPropertyData(defaultOutputDeviceID, &muteAddress, 0, nil, &muteSize, &isMuted)
            if status != noErr {
                muteAddress.mElement = 2
                AudioObjectGetPropertyData(defaultOutputDeviceID, &muteAddress, 0, nil, &muteSize, &isMuted)
            }
        }
        
        return (volume, isMuted != 0)
    }
    
    private func setSystemVolumeCoreAudio(volume: Float, mute: Bool) {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &defaultOutputDeviceID)
        
        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var vol = volume
        var status = AudioObjectSetPropertyData(defaultOutputDeviceID, &volAddress, 0, nil, UInt32(MemoryLayout<Float>.size), &vol)
        if status != noErr {
            volAddress.mElement = 1
            status = AudioObjectSetPropertyData(defaultOutputDeviceID, &volAddress, 0, nil, UInt32(MemoryLayout<Float>.size), &vol)
            if status != noErr {
                volAddress.mElement = 2
                status = AudioObjectSetPropertyData(defaultOutputDeviceID, &volAddress, 0, nil, UInt32(MemoryLayout<Float>.size), &vol)
                if status != noErr {
                    var systemVolAddress = AudioObjectPropertyAddress(
                        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                        mScope: kAudioDevicePropertyScopeOutput,
                        mElement: kAudioObjectPropertyElementMain
                    )
                    AudioHardwareServiceSetPropertyData(defaultOutputDeviceID, &systemVolAddress, 0, nil, UInt32(MemoryLayout<Float>.size), &vol)
                }
            }
        }
        
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var muteVal: UInt32 = mute ? 1 : 0
        status = AudioObjectSetPropertyData(defaultOutputDeviceID, &muteAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &muteVal)
        if status != noErr {
            muteAddress.mElement = 1
            AudioObjectSetPropertyData(defaultOutputDeviceID, &muteAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &muteVal)
            muteAddress.mElement = 2
            AudioObjectSetPropertyData(defaultOutputDeviceID, &muteAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &muteVal)
        }
    }
    
    private var muteEnforcerTimer: Timer?
    private var targetMicVolume: Float = 0.5
    private var isMicMuted: Bool = false
    private var isEnforcing: Bool = false
    
    func getMicVolume() -> (Float, Bool) {
        let scriptSource = "input volume of (get volume settings)"
        if let script = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            let descriptor = script.executeAndReturnError(&error)
            if error == nil {
                let vol = descriptor.int32Value
                if vol >= 0 && vol <= 100 {
                    return (Float(vol) / 100.0, vol == 0)
                }
            }
        }
        
        return (0.5, false)
    }
    
    func setMicVolume(volume: Float, mute: Bool) {
        targetMicVolume = volume
        isMicMuted = mute
        
        if mute {
            startMuteEnforcer()
        } else {
            stopMuteEnforcer()
        }
        
        applyMicVolumeAndMute(volume: volume, mute: mute)
    }
    
    private func startMuteEnforcer() {
        if muteEnforcerTimer == nil {
            DispatchQueue.main.async {
                self.muteEnforcerTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    if self.isMicMuted {
                        self.applyMicVolumeAndMute(volume: 0, mute: true)
                    }
                }
            }
        }
    }
    
    private func stopMuteEnforcer() {
        DispatchQueue.main.async {
            self.muteEnforcerTimer?.invalidate()
            self.muteEnforcerTimer = nil
        }
    }
    
    private func applyMicVolumeAndMute(volume: Float, mute: Bool) {
        guard !isEnforcing else { return }
        isEnforcing = true
        
        // 1. Zmiana dla domyślnego urządzenia przez AppleScript (100% niezawodności)
        DispatchQueue.global(qos: .userInitiated).async {
            let targetVolume = mute ? 0 : Int(volume * 100)
            let scriptSource = "set volume input volume \(targetVolume)"
            if let script = NSAppleScript(source: scriptSource) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
            }
            
            // 2. Zmiana dla WSZYSTKICH urządzeń wejściowych
            self.setAllInputDevicesVolume(volume: volume, mute: mute)
            DispatchQueue.main.async {
                self.isEnforcing = false
            }
        }
    }
    
    private func setAllInputDevicesVolume(volume: Float, mute: Bool) {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &devices)
        
        for device in devices {
            var streamAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            AudioObjectGetPropertyDataSize(device, &streamAddr, 0, nil, &streamSize)
            
            // Jeśli urządzenie ma kanał wejściowy (jest mikrofonem)
            if streamSize > 0 {
                var vol = volume
                var volAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyVolumeScalar,
                    mScope: kAudioDevicePropertyScopeInput,
                    mElement: kAudioObjectPropertyElementMain
                )
                
                volAddress.mElement = 0
                AudioObjectSetPropertyData(device, &volAddress, 0, nil, UInt32(MemoryLayout<Float>.size), &vol)
                volAddress.mElement = 1
                AudioObjectSetPropertyData(device, &volAddress, 0, nil, UInt32(MemoryLayout<Float>.size), &vol)
                volAddress.mElement = 2
                AudioObjectSetPropertyData(device, &volAddress, 0, nil, UInt32(MemoryLayout<Float>.size), &vol)
                
                var systemVolAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                    mScope: kAudioDevicePropertyScopeInput,
                    mElement: kAudioObjectPropertyElementMain
                )
                AudioHardwareServiceSetPropertyData(device, &systemVolAddress, 0, nil, UInt32(MemoryLayout<Float>.size), &vol)
                
                var muteAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyMute,
                    mScope: kAudioDevicePropertyScopeInput,
                    mElement: kAudioObjectPropertyElementMain
                )
                var muteVal: UInt32 = mute ? 1 : 0
                muteAddress.mElement = 0
                AudioObjectSetPropertyData(device, &muteAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &muteVal)
                muteAddress.mElement = 1
                AudioObjectSetPropertyData(device, &muteAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &muteVal)
                muteAddress.mElement = 2
                AudioObjectSetPropertyData(device, &muteAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &muteVal)
            }
        }
    }

    func changeVolume(increase: Bool, completion: @escaping (Int, Bool) -> Void) {
        DispatchQueue.main.async {
            if !self.isInitialized {
                let current = self.getSystemVolume()
                self.cachedVolume = Int(current.0 * 100)
                self.cachedMuted = current.1
                self.isInitialized = true
            }
            
            let step = 6.25
            var newVol = Double(self.cachedVolume) + (increase ? step : -step)
            if newVol < 0 { newVol = 0 }
            if newVol > 100 { newVol = 100 }
            
            self.cachedVolume = Int(newVol)
            self.cachedMuted = false
            self.lastProgrammaticChangeTime = Date()
            
            let targetVol = self.cachedVolume
            let targetMuted = self.cachedMuted
            
            self.setSystemVolumeCoreAudio(volume: Float(targetVol) / 100.0, mute: targetMuted)
            completion(targetVol, targetMuted)
        }
    }
    
    func fetchCurrentVolume(completion: @escaping (Int, Bool) -> Void) {
        queue.async {
            if Date().timeIntervalSince(self.lastProgrammaticChangeTime) < 0.5 {
                DispatchQueue.main.async {
                    completion(self.cachedVolume, self.cachedMuted)
                }
                return
            }
            
            let current = self.getSystemVolume()
            let newVol = Int(current.0 * 100)
            let isMuted = current.1
            
            DispatchQueue.main.async {
                self.cachedVolume = newVol
                self.cachedMuted = isMuted
                self.isInitialized = true
                completion(newVol, isMuted)
            }
        }
    }
    
    func increaseVolume(completion: @escaping (Int, Bool) -> Void) {
        changeVolume(increase: true, completion: completion)
    }
    
    func decreaseVolume(completion: @escaping (Int, Bool) -> Void) {
        changeVolume(increase: false, completion: completion)
    }
    
    func setVolume(to level: Int, completion: @escaping (Int, Bool) -> Void) {
        DispatchQueue.main.async {
            if !self.isInitialized {
                self.isInitialized = true
            }
            
            var newVol = level
            if newVol < 0 { newVol = 0 }
            if newVol > 100 { newVol = 100 }
            
            self.cachedVolume = newVol
            self.cachedMuted = false
            self.lastProgrammaticChangeTime = Date()
            
            let targetVol = self.cachedVolume
            let targetMuted = self.cachedMuted
            
            self.setSystemVolumeCoreAudio(volume: Float(targetVol) / 100.0, mute: targetMuted)
            completion(targetVol, targetMuted)
        }
    }
    
    func toggleMute(completion: @escaping (Int, Bool) -> Void) {
        DispatchQueue.main.async {
            if !self.isInitialized {
                let current = self.getSystemVolume()
                self.cachedVolume = Int(current.0 * 100)
                self.cachedMuted = current.1
                self.isInitialized = true
            }
            
            self.cachedMuted.toggle()
            self.lastProgrammaticChangeTime = Date()
            
            let targetVol = self.cachedVolume
            let targetMuted = self.cachedMuted
            
            self.setSystemVolumeCoreAudio(volume: Float(targetVol) / 100.0, mute: targetMuted)
            completion(targetVol, targetMuted)
        }
    }
}

class BrightnessManager {
    static let shared = BrightnessManager()
    
    private let queue = DispatchQueue(label: "com.visor.brightnessQueue")
    
    private var DisplayServicesGetBrightness: (@convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32)?
    private var DisplayServicesSetBrightness: (@convention(c) (CGDirectDisplayID, Float) -> Int32)?
    
    init() {
        let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
        if handle != nil {
            if let getSym = dlsym(handle, "DisplayServicesGetBrightness") {
                typealias GetFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
                DisplayServicesGetBrightness = unsafeBitCast(getSym, to: GetFunc.self)
            }
            if let setSym = dlsym(handle, "DisplayServicesSetBrightness") {
                typealias SetFunc = @convention(c) (CGDirectDisplayID, Float) -> Int32
                DisplayServicesSetBrightness = unsafeBitCast(setSym, to: SetFunc.self)
            }
        } else {
        }
    }
    
    func fetchCurrentBrightness(completion: @escaping (Int) -> Void) {
        queue.async {
            var brightness: Float = 0.5
            if let getFunc = self.DisplayServicesGetBrightness {
                let _ = getFunc(CGMainDisplayID(), &brightness)
            }
            let intBrightness = Int(brightness * 100)
            DispatchQueue.main.async {
                completion(intBrightness)
            }
        }
    }
    
    func changeBrightness(increase: Bool, completion: @escaping (Int) -> Void) {
        queue.async {
            var currentBrightness: Float = 0.5
            if let getFunc = self.DisplayServicesGetBrightness {
                let _ = getFunc(CGMainDisplayID(), &currentBrightness)
            }
            
            let step: Float = 1.0 / 16.0
            var newBrightness = increase ? currentBrightness + step : currentBrightness - step
            newBrightness = max(0.0, min(1.0, newBrightness))
            
            if let setFunc = self.DisplayServicesSetBrightness {
                let _ = setFunc(CGMainDisplayID(), newBrightness)
            }
            
            let intBrightness = Int(newBrightness * 100)
            DispatchQueue.main.async {
                completion(intBrightness)
            }
        }
    }
    
    func increaseBrightness(completion: @escaping (Int) -> Void) {
        changeBrightness(increase: true, completion: completion)
    }
    
    func decreaseBrightness(completion: @escaping (Int) -> Void) {
        changeBrightness(increase: false, completion: completion)
    }
    
    func setBrightness(to level: Int, completion: @escaping (Int) -> Void) {
        queue.async {
            var newBrightness = Float(level) / 100.0
            newBrightness = max(0.0, min(1.0, newBrightness))
            
            if let setFunc = self.DisplayServicesSetBrightness {
                let _ = setFunc(CGMainDisplayID(), newBrightness)
            }
            
            let intBrightness = Int(newBrightness * 100)
            DispatchQueue.main.async {
                completion(intBrightness)
            }
        }
    }
}
