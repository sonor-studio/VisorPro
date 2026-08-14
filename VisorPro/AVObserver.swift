import Cocoa
import CoreAudio
import CoreMediaIO
import AVFoundation

class AVObserver {
    weak var manager: MediaKeyManager?
    
    private var micDevices = [AudioDeviceID]()
    private var cameraDevices = [CMIODeviceID]()
    
    init(manager: MediaKeyManager) {
        self.manager = manager
    }
    
    func startObserving() {
        setupMicObserver()
        setupCameraObserver()
    }
    
    private func setupMicObserver() {
        var devicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.rebuildMicDevices()
        }
        
        rebuildMicDevices()
    }
    
    private func rebuildMicDevices() {
        // We don't strictly need to remove old listeners because AudioObjectAddPropertyListenerBlock with the same block on the same device just adds it or is safe, but ideally we'd remove. For simplicity, we just rebuild the list.
        micDevices.removeAll()
        
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
            if streamSize > 0 {
                if !micDevices.contains(device) {
                    micDevices.append(device)
                    
                    var runningAddress = AudioObjectPropertyAddress(
                        mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                        mScope: kAudioObjectPropertyScopeGlobal,
                        mElement: kAudioObjectPropertyElementMain
                    )
                    
                    AudioObjectAddPropertyListenerBlock(device, &runningAddress, DispatchQueue.main) { [weak self] _, _ in
                        self?.checkMicState()
                    }
                }
            }
        }
        
        checkMicState()
    }
    
    private func checkMicState() {
        var isAnyRunning = false
        var activeDeviceName = ""
        
        for device in micDevices {
            var runningAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            var isRunning: UInt32 = 0
            var size: UInt32 = UInt32(MemoryLayout<UInt32>.size)
            let err = AudioObjectGetPropertyData(device, &runningAddress, 0, nil, &size, &isRunning)
            if err == 0 && isRunning > 0 {
                isAnyRunning = true
                activeDeviceName = getAudioDeviceName(deviceID: device)
                break
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.micDebounceTimer?.invalidate()
            
            if isAnyRunning {
                if self.manager?.isMicActive != true {
                    self.manager?.triggerMicIndicator(isActive: true, deviceName: activeDeviceName)
                }
            } else {
                self.micDebounceTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
                    if self.manager?.isMicActive == true {
                        self.manager?.triggerMicIndicator(isActive: false, deviceName: "")
                    }
                }
            }
        }
    }
    
    private func setupCameraObserver() {
        var propertyAddress = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        
        var dataSize: UInt32 = 0
        var dataUsed: UInt32 = 0
        CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
        
        let deviceCount = Int(dataSize) / MemoryLayout<CMIODeviceID>.size
        var devices = [CMIODeviceID](repeating: 0, count: deviceCount)
        
        CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &propertyAddress, 0, nil, dataSize, &dataUsed, &devices)
        
        for device in devices {
            cameraDevices.append(device)
            var runningAddress = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
            )
            
            CMIOObjectAddPropertyListenerBlock(device, &runningAddress, DispatchQueue.main) { [weak self] _, _ in
                self?.checkCameraState()
            }
        }
        
        checkCameraState()
    }
    
    private var cameraDebounceTimer: Timer?
    private var micDebounceTimer: Timer?
    
    private func checkCameraState() {
        var isAnyRunning = false
        var activeDeviceName = ""
        
        for device in cameraDevices {
            var runningAddress = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
            )
            
            var isRunning: UInt32 = 0
            var size: UInt32 = UInt32(MemoryLayout<UInt32>.size)
            let err = CMIOObjectGetPropertyData(device, &runningAddress, 0, nil, size, &size, &isRunning)
            if err == 0 && isRunning > 0 {
                isAnyRunning = true
                activeDeviceName = getCameraDeviceName(deviceID: device)
                break
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.cameraDebounceTimer?.invalidate()
            
            if isAnyRunning {
                // If it's running, update immediately
                if self.manager?.isCameraActive != true {
                    self.manager?.triggerCameraIndicator(isActive: true, deviceName: activeDeviceName)
                }
            } else {
                // If it's NOT running, debounce by 1.5 seconds to ignore brief dropouts during macOS Reaction injection
                self.cameraDebounceTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
                    if self.manager?.isCameraActive == true {
                        self.manager?.triggerCameraIndicator(isActive: false, deviceName: "")
                    }
                }
            }
        }
    }

    
    private func getAudioDeviceName(deviceID: AudioDeviceID) -> String {
        var name = ""
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        if AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr {
            var nameCF: CFString?
            var size2 = UInt32(MemoryLayout<CFString?>.size)
            if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size2, &nameCF) == noErr {
                if let nameString = nameCF as String? {
                    name = nameString
                }
            }
        }
        return name
    }
    
    private func getCameraDeviceName(deviceID: CMIODeviceID) -> String {
        var name = ""
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOObjectPropertyName),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        var size: UInt32 = 0
        if CMIOObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr {
            var nameCF: CFString?
            var size2 = UInt32(MemoryLayout<CFString?>.size)
            var dataUsed: UInt32 = 0
            if CMIOObjectGetPropertyData(deviceID, &address, 0, nil, size2, &dataUsed, &nameCF) == noErr {
                if let nameString = nameCF as String? {
                    name = nameString
                }
            }
        }
        return name
    }
}
