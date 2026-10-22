import SwiftUI
import AppKit

extension MediaKeyManager {
    
    func updateFocusReminderTimer() {
        focusReminderTimer?.invalidate()
        focusReminderTimer = nil
        
        if enableFocus && enableFocusReminder && isFocusModeActive {
            let interval = TimeInterval(focusReminderInterval * 60)
            
            focusReminderTimer = Timer.scheduledTimerInCommonModes(withTimeInterval: interval, repeats: false) { [weak self] _ in
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
                        if self.focusActiveDate == nil {
                            self.focusActiveDate = self.activeFocusDetails?.startDate ?? Date().addingTimeInterval(-Double(self.focusReminderInterval * 60))
                        }
                        withAnimation(.easeInOut(duration: 0.15)) {
                            self.showFocusIndicator = true
                            self.notifyOverlayStateChanged()
                            self.overlayTriggerTimes["focus"] = Date()
                        }
                        self.focusTimer = Timer.scheduledTimerInCommonModes(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { _ in
                            withAnimation(.easeInOut(duration: 0.25)) {
                                self.showFocusIndicator = false
                            }
                        }
                        // Schedule the next reminder instead of using repeats: true
                        // This prevents runaway repeating timers from spamming right after Mac wakes up
                        self.updateFocusReminderTimer()
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
    
    // MARK: - Microphone Mute Reminder
    
    func updateMicMuteReminderState() {
        if enablePrivacy && enableMicMuteReminder {
            micMuteObserver?.startObserving()
        } else {
            micMuteObserver?.stopObserving()
            cancelMicMuteReminderTimer()
        }
    }
    
    func startMicMuteReminderTimer() {
        micMuteReminderTimer?.invalidate()
        micMuteReminderTimer = nil
        
        guard enablePrivacy && enableMicMuteReminder else { return }
        guard micMuteObserver?.isMicMuted == true else { return }
        
        let interval = TimeInterval(micMuteReminderInterval * 60)
        
        micMuteReminderTimer = Timer.scheduledTimerInCommonModes(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.triggerMicMuteReminder()
        }
    }
    
    func updateMicMuteReminderTimer() {
        if micMuteObserver?.isMicMuted == true {
            startMicMuteReminderTimer()
        } else {
            cancelMicMuteReminderTimer()
        }
    }
    
    func cancelMicMuteReminderTimer() {
        micMuteReminderTimer?.invalidate()
        micMuteReminderTimer = nil
        if isMicMuteReminder {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isMicMuteReminder = false
                self.micMutedDate = nil
                if self.showMicIndicator && !self.isMicActive {
                    if self.isOverlayHoveredOrExpanded("mic") { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.showMicIndicator = false
                    }
                }
            }
        }
    }
    
    func triggerMicMuteReminder() {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }
        guard enablePrivacy && enableMicMuteReminder else { return }
        guard micMuteObserver?.isMicMuted == true else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.micTimer?.invalidate()
            if self.micMutedDate == nil {
                self.micMutedDate = Date().addingTimeInterval(-Double(self.micMuteReminderInterval * 60))
            }
            
            let pos = self.getOverlayPosition(for: "micOverlayPosition")
            self.dismissCollidingIndicators(newPosition: pos, source: "mic")
            
            let executeShow = { [weak self] in
                guard let self = self else { return }
                self.isMicMuteReminder = true
                self.micEventId = UUID()
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.showMicIndicator = true
                    self.notifyOverlayStateChanged()
                    self.overlayTriggerTimes["mic"] = Date()
                }
                
                if !self.isOverlayHoveredOrExpanded("mic") {
                    self.micTimer = Timer.scheduledTimerInCommonModes(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                        guard let self = self, !self.isOverlayHoveredOrExpanded("mic") else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self.showMicIndicator = false
                            self.isMicMuteReminder = false
                        }
                    }
                }
                
                // Schedule next reminder instead of using repeats: true
                // This prevents runaway repeating timers from spamming right after Mac wakes up
                self.startMicMuteReminderTimer()
            }
            
            if self.showMicIndicator {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.showMicIndicator = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    executeShow()
                }
            } else {
                executeShow()
            }
        }
    }
    
    func triggerFocusIndicator(isActive: Bool, modeName: String?, colorName: String = "systemIndigoColor", symbol: String = "moon.fill", isSwitched: Bool = false, details: ActiveFocusDetails? = nil) {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }

        // Notify NativeOverlayDismisser so it can disambiguate native empty banners
        NativeOverlayDismisser.shared.onSystemEvent(type: .focus)

        if !enableFocus { return }
        if isActive && !notifyOnFocusOn { return }
        if !isActive && !notifyOnFocusOff { return }
        
        // Dismiss the native macOS Focus pill overlay (from MenuBarAgent)
        
        playNotificationSound(named: isActive ? soundOnFocusOn : soundOnFocusOff)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.focusTimer?.invalidate()
            
            let pos = self.getOverlayPosition(for: "focusOverlayPosition")
            self.dismissCollidingIndicators(newPosition: pos, source: "focus")
            
            let executeShow = { [weak self] in
                guard let self = self else { return }
                
                self.isFocusModeActive = isActive
                self.focusModeName = modeName ?? "Focus"
                self.focusColorName = colorName
                self.focusSymbol = symbol
                self.isFocusReminder = false
                self.isFocusSwitched = isSwitched
                if isActive {
                    self.focusActiveDate = details?.startDate ?? self.focusActiveDate ?? Date()
                    self.activeFocusDetails = details
                    self.lastEndedFocusDetails = nil
                } else {
                    if var lastDetails = self.activeFocusDetails {
                        lastDetails.endedAt = Date()
                        self.lastEndedFocusDetails = lastDetails
                    } else if var d = details {
                        d.endedAt = Date()
                        self.lastEndedFocusDetails = d
                    } else if let start = self.focusActiveDate {
                        self.lastEndedFocusDetails = MediaKeyManager.ActiveFocusDetails(startDate: start, endedAt: Date(), endedReason: "turned off")
                    }
                    self.focusActiveDate = nil
                    self.activeFocusDetails = nil
                }
                
                self.updateFocusReminderTimer()
                
                self.focusEventId = UUID()
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.showFocusIndicator = true
                    self.notifyOverlayStateChanged()
                    self.overlayTriggerTimes["focus"] = Date()
                }
                if !self.isOverlayHoveredOrExpanded("focus") {
                    self.focusTimer = Timer.scheduledTimerInCommonModes(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                        guard let self = self, !self.isOverlayHoveredOrExpanded("focus") else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self.showFocusIndicator = false
                        }
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
            self.isMicMuteReminder = false
            
            if isActive {
                self.micTimer?.invalidate()
                self.micEventId = UUID()
                
                if self.showMicIndicator && !self.isOverlayHoveredOrExpanded("mic") {
                    self.isMicTimerScheduledInstantly = true
                    self.micTimer = Timer.scheduledTimerInCommonModes(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                        guard let self = self, !self.isOverlayHoveredOrExpanded("mic") else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self.showMicIndicator = false
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
                if !self.isOverlayHoveredOrExpanded("mic") {
                    self.showMicIndicator = false
                }
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
            
            if !self.isOverlayHoveredOrExpanded("mic") {
                self.micTimer = Timer.scheduledTimerInCommonModes(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                    guard let self = self, !self.isOverlayHoveredOrExpanded("mic") else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self.showMicIndicator = false
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
                
                if self.showCameraIndicator && !self.isOverlayHoveredOrExpanded("camera") {
                    self.isCameraTimerScheduledInstantly = true
                    self.cameraTimer = Timer.scheduledTimerInCommonModes(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                        guard let self = self, !self.isOverlayHoveredOrExpanded("camera") else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self.showCameraIndicator = false
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
            
            if !self.notifyOnCameraOff {
                if !self.isOverlayHoveredOrExpanded("camera") {
                    self.showCameraIndicator = false
                }
                return
            }
            
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
            
            if !self.isOverlayHoveredOrExpanded("camera") {
                self.cameraTimer = Timer.scheduledTimerInCommonModes(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                    guard let self = self, !self.isOverlayHoveredOrExpanded("camera") else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self.showCameraIndicator = false
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
            
            if !self.isOverlayHoveredOrExpanded("location") {
                self.locationTimer = Timer.scheduledTimerInCommonModes(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                    guard let self = self, !self.isOverlayHoveredOrExpanded("location") else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self.showLocationIndicator = false
                        self.isLocationActive = false
                    }
                }
            }
        }
    }
}
