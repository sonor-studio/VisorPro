import Foundation
import CoreAudio
import Combine

class AirPodsModeObserver {
    private var defaultOutputDeviceID: AudioDeviceID = 0
    private let lstmSelector: UInt32 = 0x6c73746d // 'lstm'
    
    private var defaultOutputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    
    private var lstmAddress = AudioObjectPropertyAddress(
        mSelector: 0x6c73746d,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    
    private var modeChangeCallback: ((Int) -> Void)?
    
    init(modeChangeCallback: @escaping (Int) -> Void) {
        self.modeChangeCallback = modeChangeCallback
    }
    
    func start() {
        let err = AudioObjectAddPropertyListenerBlock(UInt32(kAudioObjectSystemObject), &defaultOutputAddress, nil) { [weak self] (numberAddresses, addresses) in
            self?.handleDefaultOutputChanged()
        }
        
        if err == noErr {
            handleDefaultOutputChanged()
        }
    }
    
    func stop() {
        AudioObjectRemovePropertyListenerBlock(UInt32(kAudioObjectSystemObject), &defaultOutputAddress, nil, { _, _ in })
        removeLstmListener()
    }
    
    private func handleDefaultOutputChanged() {
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var newDefaultOutput: AudioDeviceID = 0
        let err = AudioObjectGetPropertyData(UInt32(kAudioObjectSystemObject), &defaultOutputAddress, 0, nil, &size, &newDefaultOutput)
        
        if err == noErr {
            if defaultOutputDeviceID != 0 {
                removeLstmListener()
            }
            
            defaultOutputDeviceID = newDefaultOutput
            
            if hasLstmProperty(deviceID: defaultOutputDeviceID) {
                if let scope = findLstmScope(deviceID: defaultOutputDeviceID) {
                    lstmAddress.mScope = scope
                    addLstmListener(deviceID: defaultOutputDeviceID)
                    
                    if let mode = readLstmMode(deviceID: defaultOutputDeviceID, scope: scope) {
                        DispatchQueue.main.async {
                            // Silently update the state without triggering the callback which would fire the animation
                            // Do not set previousAirPodsModeValue to 1 on initial load
                            OverlayStateRelay.shared.airPodsModeValue = mode
                        }
                    }
                }
            }
        }
    }
    
    private func hasLstmProperty(deviceID: AudioDeviceID) -> Bool {
        var size: UInt32 = 0
        var testAddress = AudioObjectPropertyAddress(
            mSelector: lstmSelector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let err = AudioObjectGetPropertyDataSize(deviceID, &testAddress, 0, nil, &size)
        return err == noErr
    }
    
    private func findLstmScope(deviceID: AudioDeviceID) -> AudioObjectPropertyScope? {
        let scopes: [AudioObjectPropertyScope] = [
            kAudioObjectPropertyScopeGlobal,
            kAudioObjectPropertyScopeOutput,
            kAudioObjectPropertyScopeInput,
            1735159650
        ]
        
        for scope in scopes {
            var size: UInt32 = 0
            var testAddress = AudioObjectPropertyAddress(
                mSelector: lstmSelector,
                mScope: scope,
                mElement: kAudioObjectPropertyElementWildcard
            )
            let err = AudioObjectGetPropertyDataSize(deviceID, &testAddress, 0, nil, &size)
            if err == noErr {
                return scope
            }
        }
        return nil
    }
    
    private func addLstmListener(deviceID: AudioDeviceID) {
        let err = AudioObjectAddPropertyListenerBlock(deviceID, &lstmAddress, nil) { [weak self] (numberAddresses, addresses) in
            guard let self = self else { return }
            for i in 0..<Int(numberAddresses) {
                if addresses[i].mSelector == self.lstmSelector {
                    if let mode = self.readLstmMode(deviceID: deviceID, scope: self.lstmAddress.mScope) {
                        self.modeChangeCallback?(mode)
                    }
                }
            }
        }
        if err != noErr {
            LogManager.shared.log("Failed to add lstm listener: \(err)", level: "ERROR")
        }
    }
    
    private func removeLstmListener() {
        if defaultOutputDeviceID != 0 {
            AudioObjectRemovePropertyListenerBlock(defaultOutputDeviceID, &lstmAddress, nil, { _, _ in })
        }
    }
    
    private func readLstmMode(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Int? {
        var mode: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: lstmSelector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        let err = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &mode)
        return err == noErr ? Int(mode) : nil
    }
    
    func setMode(_ mode: Int) -> Bool {
        guard defaultOutputDeviceID != 0 else { return false }
        var targetMode = UInt32(mode)
        let size = UInt32(MemoryLayout<UInt32>.size)
        
        let err = AudioObjectSetPropertyData(defaultOutputDeviceID, &lstmAddress, 0, nil, size, &targetMode)
        return err == noErr
    }
}
