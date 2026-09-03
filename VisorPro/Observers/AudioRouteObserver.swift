import Foundation
import CoreAudio
import Dispatch
import AudioToolbox



class AudioRouteObserver {
    private weak var manager: MediaKeyManager?
    private var currentDeviceID: AudioDeviceID = 0
    private var lastRouteChangeTime: Date = Date.distantPast
    
    private lazy var volumeListenerBlock: AudioObjectPropertyListenerBlock = { [weak self] (inNumberAddresses, inAddresses) in
        self?.handleVolumeChanged()
    }
    
    private lazy var muteListenerBlock: AudioObjectPropertyListenerBlock = { [weak self] (inNumberAddresses, inAddresses) in
        self?.handleVolumeChanged()
    }
    init(manager: MediaKeyManager) {
        self.manager = manager
        startObserving()
        updateCurrentDeviceAndListen()
    }
    
    func startObserving() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, DispatchQueue.main) { [weak self] (inNumberAddresses, inAddresses) in
            self?.handleRouteChanged()
        }
        
        if status != noErr {
        }
    }
    
    private func handleRouteChanged() {
        lastRouteChangeTime = Date()
        updateCurrentDeviceAndListen()
        
        guard let manager = manager, !manager.useSystemOSD else { return }
        if currentDeviceID != 0 {
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var deviceName: CFString?
            var nameSize = UInt32(MemoryLayout<CFString?>.size)
            let status = withUnsafeMutablePointer(to: &deviceName) { ptr in
                AudioObjectGetPropertyData(currentDeviceID, &nameAddress, 0, nil, &nameSize, ptr)
            }
            
            if status == noErr, let name = deviceName as String? {
                manager.lastAction = "Audio output: \(name)"
            }
        }
        
        handleVolumeChanged()
    }
    
    private func updateCurrentDeviceAndListen() {
        var deviceID = AudioDeviceID(0)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceID)
        
        let elements: [UInt32] = [
            kAudioObjectPropertyElementMain,
            1, // Channel 1 (Left)
            2  // Channel 2 (Right)
        ]
        
        let selectors: [AudioObjectPropertySelector] = [
            kAudioDevicePropertyVolumeScalar
        ]
        
        if currentDeviceID != 0 {
            for element in elements {
                for selector in selectors {
                    var volAddr = AudioObjectPropertyAddress(
                        mSelector: selector,
                        mScope: kAudioObjectPropertyScopeOutput,
                        mElement: element
                    )
                    AudioObjectRemovePropertyListenerBlock(currentDeviceID, &volAddr, DispatchQueue.main, volumeListenerBlock)
                }
                var muteAddr = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyMute,
                    mScope: kAudioObjectPropertyScopeOutput,
                    mElement: element
                )
                AudioObjectRemovePropertyListenerBlock(currentDeviceID, &muteAddr, DispatchQueue.main, muteListenerBlock)
            }
        }
        
        currentDeviceID = deviceID
        
        if currentDeviceID != 0 {
            for element in elements {
                for selector in selectors {
                    var volAddr = AudioObjectPropertyAddress(
                        mSelector: selector,
                        mScope: kAudioObjectPropertyScopeOutput,
                        mElement: element
                    )
                    AudioObjectAddPropertyListenerBlock(currentDeviceID, &volAddr, DispatchQueue.main, volumeListenerBlock)
                }
                var muteAddr = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyMute,
                    mScope: kAudioObjectPropertyScopeOutput,
                    mElement: element
                )
                AudioObjectAddPropertyListenerBlock(currentDeviceID, &muteAddr, DispatchQueue.main, muteListenerBlock)
            }
        }
    }
    
    func handleVolumeChanged() {
        guard let manager = manager, !manager.useSystemOSD else { return }
        
        let timeSinceRoute = Date().timeIntervalSince(lastRouteChangeTime)
        
        VolumeManager.shared.fetchCurrentVolume { [weak manager] vol, muted in
            guard let mgr = manager else { return }
            
            if mgr.currentVolume == vol && mgr.isMuted == muted {
                return
            }
            
            mgr.currentVolume = vol
            mgr.isMuted = muted
            mgr.currentAudioDeviceName = VolumeManager.shared.getCurrentAudioDeviceName()
            
            if timeSinceRoute > 2.5 {
                mgr.triggerVolumeIndicator()
            }
        }
    }
}
