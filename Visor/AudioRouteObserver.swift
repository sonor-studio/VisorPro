import Foundation
import CoreAudio
import Dispatch

class AudioRouteObserver {
    private weak var manager: MediaKeyManager?
    private var currentDeviceID: AudioDeviceID = 0
    
    private lazy var volumeListenerBlock: AudioObjectPropertyListenerBlock = { [weak self] (inNumberAddresses, inAddresses) in
        self?.handleVolumeChanged()
    }
    
    private lazy var muteListenerBlock: AudioObjectPropertyListenerBlock = { [weak self] (inNumberAddresses, inAddresses) in
        self?.handleVolumeChanged()
    }
    
    init(manager: MediaKeyManager) {
        self.manager = manager
        startObserving()
        // Inicjalizujemy dla początkowego urządzenia
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
            print("Błąd podczas rejestrowania nasłuchiwacza trasy CoreAudio: \(status)")
        }
    }
    
    private func handleRouteChanged() {
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
            let status = AudioObjectGetPropertyData(currentDeviceID, &nameAddress, 0, nil, &nameSize, &deviceName)
            
            if status == noErr, let name = deviceName as String? {
                manager.lastAction = "Wyjście audio: \(name)"
            }
        }
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
        
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if currentDeviceID != 0 {
            AudioObjectRemovePropertyListenerBlock(currentDeviceID, &volumeAddress, DispatchQueue.main, volumeListenerBlock)
            AudioObjectRemovePropertyListenerBlock(currentDeviceID, &muteAddress, DispatchQueue.main, muteListenerBlock)
        }
        
        currentDeviceID = deviceID
        
        if currentDeviceID != 0 {
            AudioObjectAddPropertyListenerBlock(currentDeviceID, &volumeAddress, DispatchQueue.main, volumeListenerBlock)
            AudioObjectAddPropertyListenerBlock(currentDeviceID, &muteAddress, DispatchQueue.main, muteListenerBlock)
        }
    }
    
    private func handleVolumeChanged() {
        guard let manager = manager, !manager.useSystemOSD else { return }
        
        VolumeManager.shared.fetchCurrentVolume { [weak manager] vol, muted in
            guard let mgr = manager else { return }
            
            // Unikamy zapętlenia z klawiatury (skrypt wywołuje OSD ręcznie)
            // ale jeśli zmiana pochodzi z zewnątrz (AirPods), to triggerVolumeIndicator odpali HUD
            mgr.currentVolume = vol
            mgr.isMuted = muted
            mgr.currentAudioDeviceName = VolumeManager.shared.getCurrentAudioDeviceName()
            mgr.triggerVolumeIndicator()
        }
    }
}
