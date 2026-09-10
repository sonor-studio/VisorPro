import SwiftUI
import AppKit

extension MediaKeyManager {
    
    func updateFocusReminderTimer() {
        focusReminderTimer?.invalidate()
        focusReminderTimer = nil
        
        if enableFocus && enableFocusReminder && isFocusModeActive {
            let interval = TimeInterval(focusReminderInterval * 60)
            focusReminderTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                
                // Show reminder without playing a sound (or play a subtle sound if requested, but default is visual)
                DispatchQueue.main.async {
                    self.focusTimer?.invalidate()
                    
                    let pos = self.getOverlayPosition(for: "focusOverlayPosition")
                    self.dismissCollidingIndicators(newPosition: pos, source: "focus")
                    
                    let executeShow = {
                        self.isFocusReminder = true
                        self.isFocusSwitched = false
                        self.focusEventId = UUID()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            self.showFocusIndicator = true
                            self.notifyOverlayStateChanged()
                            self.overlayTriggerTimes["focus"] = Date()
                        }
                        self.focusTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { _ in
                            withAnimation(.easeInOut(duration: 0.25)) {
                                self.showFocusIndicator = false
                            }
                        }
                    }
                    
                    if self.showFocusIndicator {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self.showFocusIndicator = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            executeShow()
                        }
                    } else {
                        executeShow()
                    }
                }
            }
        }
    }
    
    func triggerFocusIndicator(isActive: Bool, modeName: String?, colorName: String = "systemIndigoColor", symbol: String = "moon.fill", isSwitched: Bool = false, details: ActiveFocusDetails? = nil) {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }

        if !enableFocus { return }
        if isActive && !notifyOnFocusOn { return }
        if !isActive && !notifyOnFocusOff { return }
        
        playNotificationSound(named: isActive ? soundOnFocusOn : soundOnFocusOff)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.focusTimer?.invalidate()
            
            let pos = self.getOverlayPosition(for: "focusOverlayPosition")
            self.dismissCollidingIndicators(newPosition: pos, source: "focus")
            
            self.isFocusModeActive = isActive
            self.focusModeName = modeName ?? "Focus"
            self.focusColorName = colorName
            self.focusSymbol = symbol
            self.isFocusReminder = false
            self.isFocusSwitched = isSwitched
            if isActive {
                self.activeFocusDetails = details
                self.lastEndedFocusDetails = nil
            } else {
                if var lastDetails = self.activeFocusDetails {
                    lastDetails.endedAt = Date()
                    self.lastEndedFocusDetails = lastDetails
                } else if var details = details {
                    details.endedAt = Date()
                    self.lastEndedFocusDetails = details
                }
                self.activeFocusDetails = nil
            }
            
            self.updateFocusReminderTimer()
            
            let executeShow = { [weak self] in
                guard let self = self else { return }
                self.focusEventId = UUID()
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.showFocusIndicator = true
                    self.notifyOverlayStateChanged()
                    self.overlayTriggerTimes["focus"] = Date()
                }
                self.focusTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self?.showFocusIndicator = false
                    }
                }
            }
            
            if self.showFocusIndicator {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.showFocusIndicator = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    executeShow()
                }
            } else {
                executeShow()
            }
        }
    }
    
    func triggerMicIndicator(isActive: Bool, deviceName: String = "") {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isMicActive = isActive
            self.lastMicEventTime = Date()
            
            if isActive {
                self.micTimer?.invalidate()
                self.micEventId = UUID()
                
                if self.showMicIndicator && !self.isMicExpanded {
                    self.isMicTimerScheduledInstantly = true
                    self.micTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self?.showMicIndicator = false
                        }
                    }
                } else {
                    self.isMicTimerScheduledInstantly = false
                }
                
                self.activeMicName = deviceName.isEmpty ? "System Microphone" : deviceName
                self.activeMicClientName = ""
                self.activeMicClientBundleID = ""
                self.activeMicClientPID = nil
                self.cameraClientObserver?.fetchActiveMicClient()
                return // finalizeMicIndicator will handle the UI
            }
            
            // OFF logic
            if self.isSwitchingMic { return }
            if !self.enablePrivacy { return }
            
            if !self.notifyOnMicOff {
                self.showMicIndicator = false
                return
            }
            
            if !self.activeMicClientName.isEmpty && self.micBlocklist.contains(self.activeMicClientName) {
                self.activeMicClientName = ""
                self.activeMicClientBundleID = ""
                self.activeMicClientPID = nil
                return
            }
            
            self.playNotificationSound(named: self.soundOnMicOff)
            
            self.micTimer?.invalidate()
            let pos = self.getOverlayPosition(for: "micOverlayPosition")
            self.dismissCollidingIndicators(newPosition: pos, source: "mic")
            withAnimation(.easeInOut(duration: 0.15)) {
                self.micEventId = UUID()
                self.showMicIndicator = true; self.overlayTriggerTimes["mic"] = Date()
                self.notifyOverlayStateChanged()
            }
            
            if !self.isMicExpanded {
                self.micTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self?.showMicIndicator = false
                    }
                }
            }
        }
    }
    
    func triggerCameraIndicator(isActive: Bool, deviceName: String = "") {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isCameraActive = isActive
            
            if isActive {
                self.cameraTimer?.invalidate()
                self.cameraEventId = UUID()
                
                if self.showCameraIndicator && !self.isCameraExpanded {
                    self.isCameraTimerScheduledInstantly = true
                    self.cameraTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self?.showCameraIndicator = false
                        }
                    }
                } else {
                    self.isCameraTimerScheduledInstantly = false
                }
                
                self.activeCameraName = deviceName.isEmpty ? "Built-in Camera" : deviceName
                self.activeCameraClientName = ""
                self.activeCameraClientBundleID = ""
                self.activeCameraClientPID = nil
                self.cameraClientObserver?.fetchActiveCameraClient()
                return // finalizeCameraIndicator will handle the UI
            }
            
            // OFF logic
            if !self.enablePrivacy { return }
            
            if !self.notifyOnCameraOff { return }
            
            if !self.activeCameraClientName.isEmpty && self.cameraBlocklist.contains(self.activeCameraClientName) {
                self.activeCameraClientName = ""
                self.activeCameraClientBundleID = ""
                self.activeCameraClientPID = nil
                return
            }
            
            self.playNotificationSound(named: self.soundOnCameraOff)
            
            self.cameraTimer?.invalidate()
            let pos = self.getOverlayPosition(for: "cameraOverlayPosition")
            self.dismissCollidingIndicators(newPosition: pos, source: "camera")
            withAnimation(.easeInOut(duration: 0.15)) {
                self.cameraEventId = UUID()
                self.showCameraIndicator = true; self.overlayTriggerTimes["camera"] = Date()
                self.notifyOverlayStateChanged()
            }
            
            let camAllow = UserDefaults.standard.object(forKey: "cameraAllowExpansion") as? Bool ?? true
            if !camAllow { self.isCameraExpanded = false }
            
            if !self.isCameraExpanded {
                self.cameraTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self?.showCameraIndicator = false
                    }
                }
            }
        }
    }
    
    func triggerLocationIndicator(appName: String = "") {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if !self.enablePrivacy { return }
            if !self.notifyOnLocationOn { return }
            
            self.isLocationActive = true
            if !appName.isEmpty {
                self.activeLocationAppName = appName
            }
            
            self.playNotificationSound(named: self.soundOnLocationOn)
            
            self.locationTimer?.invalidate()
            let pos = self.getOverlayPosition(for: "locationOverlayPosition")
            self.dismissCollidingIndicators(newPosition: pos, source: "location")
            withAnimation(.easeInOut(duration: 0.15)) {
                self.locationEventId = UUID()
                self.showLocationIndicator = true; self.overlayTriggerTimes["location"] = Date()
                self.notifyOverlayStateChanged()
            }
            
            if !self.isLocationExpanded {
                self.locationTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self?.showLocationIndicator = false
                        self?.isLocationActive = false
                    }
                }
            }
        }
    }
}
