//
//  MicMuteObserver.swift
//  VisorPro
//
//  Created on 22/10/2026.
//

import Foundation
import CoreAudio
import AudioToolbox

class MicMuteObserver {
    static weak var shared: MicMuteObserver?
    
    private weak var manager: MediaKeyManager?
    private(set) var isMicMuted: Bool = false
    
    private var isObserving: Bool = false
    private var currentInputDeviceID: AudioDeviceID = 0
    private var pollTimer: Timer?
    private let queue = DispatchQueue(label: "com.visorpro.micmuteobserver", qos: .utility)
    
    private var defaultInputListenerBlock: AudioObjectPropertyListenerBlock?
    private var inputVolumeListenerBlock: AudioObjectPropertyListenerBlock?
    private var inputMuteListenerBlock: AudioObjectPropertyListenerBlock?
    
    init(manager: MediaKeyManager) {
        self.manager = manager
        MicMuteObserver.shared = self
    }
    
    deinit {
        stopObserving()
        if MicMuteObserver.shared === self {
            MicMuteObserver.shared = nil
        }
    }
    
    func startObserving() {
        guard !isObserving else { return }
        isObserving = true
        
        setupDefaultInputDeviceListener()
        rebindDeviceListeners()
        
        // Safety polling timer (throttled to 2.0s on background queue, 0% CPU impact)
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isObserving else { return }
            self.pollTimer?.invalidate()
            self.pollTimer = Timer.scheduledTimerInCommonModes(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.checkMuteState()
            }
        }
        
        checkMuteState()
    }
    
    func stopObserving() {
        guard isObserving else { return }
        isObserving = false
        
        DispatchQueue.main.async { [weak self] in
            self?.pollTimer?.invalidate()
            self?.pollTimer = nil
        }
        
        removeDefaultInputDeviceListener()
        detachDeviceListeners(deviceID: currentInputDeviceID)
        currentInputDeviceID = 0
        
        isMicMuted = false
    }
    
    // MARK: - Direct Volume Change Notification
    
    func handleVolumeChanged(volume: Float, isMuted: Bool) {
        guard isObserving else { return }
        let newlyMuted = isMuted || (volume <= 0.001)
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isObserving else { return }
            self.updateMuteState(newlyMuted: newlyMuted)
        }
    }
    
    // MARK: - CoreAudio Device Observers
    
    private func setupDefaultInputDeviceListener() {
        var defaultInputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.queue.async {
                self?.rebindDeviceListeners()
                self?.checkMuteState()
            }
        }
        self.defaultInputListenerBlock = block
        
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultInputAddress,
            DispatchQueue.main,
            block
        )
    }
    
    private func removeDefaultInputDeviceListener() {
        guard let block = defaultInputListenerBlock else { return }
        var defaultInputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultInputAddress,
            DispatchQueue.main,
            block
        )
        defaultInputListenerBlock = nil
    }
    
    private func rebindDeviceListeners() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var newDeviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &newDeviceID)
        
        guard status == noErr, newDeviceID != kAudioObjectUnknown, newDeviceID != 0 else {
            detachDeviceListeners(deviceID: currentInputDeviceID)
            currentInputDeviceID = 0
            return
        }
        
        if newDeviceID != currentInputDeviceID {
            detachDeviceListeners(deviceID: currentInputDeviceID)
            attachDeviceListeners(deviceID: newDeviceID)
            currentInputDeviceID = newDeviceID
        }
    }
    
    private func attachDeviceListeners(deviceID: AudioDeviceID) {
        guard deviceID != 0 else { return }
        
        let volBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.checkMuteState()
        }
        self.inputVolumeListenerBlock = volBlock
        
        var virtualAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        _ = AudioObjectAddPropertyListenerBlock(deviceID, &virtualAddress, DispatchQueue.main, volBlock)
        
        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        _ = AudioObjectAddPropertyListenerBlock(deviceID, &volAddress, DispatchQueue.main, volBlock)
        
        volAddress.mElement = 1
        _ = AudioObjectAddPropertyListenerBlock(deviceID, &volAddress, DispatchQueue.main, volBlock)
        
        volAddress.mElement = 2
        _ = AudioObjectAddPropertyListenerBlock(deviceID, &volAddress, DispatchQueue.main, volBlock)
        
        let mBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.checkMuteState()
        }
        self.inputMuteListenerBlock = mBlock
        
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        _ = AudioObjectAddPropertyListenerBlock(deviceID, &muteAddress, DispatchQueue.main, mBlock)
        
        muteAddress.mElement = 1
        _ = AudioObjectAddPropertyListenerBlock(deviceID, &muteAddress, DispatchQueue.main, mBlock)
    }
    
    private func detachDeviceListeners(deviceID: AudioDeviceID) {
        guard deviceID != 0 else { return }
        
        if let volBlock = inputVolumeListenerBlock {
            var virtualAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(deviceID, &virtualAddress, DispatchQueue.main, volBlock)
            
            var volAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(deviceID, &volAddress, DispatchQueue.main, volBlock)
            volAddress.mElement = 1
            AudioObjectRemovePropertyListenerBlock(deviceID, &volAddress, DispatchQueue.main, volBlock)
            volAddress.mElement = 2
            AudioObjectRemovePropertyListenerBlock(deviceID, &volAddress, DispatchQueue.main, volBlock)
            inputVolumeListenerBlock = nil
        }
        
        if let mBlock = inputMuteListenerBlock {
            var muteAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(deviceID, &muteAddress, DispatchQueue.main, mBlock)
            muteAddress.mElement = 1
            AudioObjectRemovePropertyListenerBlock(deviceID, &muteAddress, DispatchQueue.main, mBlock)
            inputMuteListenerBlock = nil
        }
    }
    
    // MARK: - Mute State Evaluation
    
    func checkMuteState() {
        queue.async { [weak self] in
            guard let self = self, self.isObserving else { return }
            let (vol, muted) = VolumeManager.shared.getMicVolume()
            let newlyMuted = muted || (vol <= 0.001)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.isObserving else { return }
                self.updateMuteState(newlyMuted: newlyMuted)
            }
        }
    }
    
    private func updateMuteState(newlyMuted: Bool) {
        if self.isMicMuted != newlyMuted {
            self.isMicMuted = newlyMuted
            VolumeManager.shared.handleExternalVolumeChanged(volume: newlyMuted ? 0 : VolumeManager.shared.getMicVolume().0, isMuted: newlyMuted)
            if newlyMuted {
                DispatchQueue.main.async {
                    OverlayStateRelay.shared.micMutedDate = Date()
                }
                self.manager?.startMicMuteReminderTimer()
            } else {
                DispatchQueue.main.async {
                    OverlayStateRelay.shared.micMutedDate = nil
                }
                self.manager?.cancelMicMuteReminderTimer()
            }
        }
    }
}
