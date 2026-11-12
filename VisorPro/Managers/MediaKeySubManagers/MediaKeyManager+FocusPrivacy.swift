import SwiftUI
import AppKit

extension MediaKeyManager {
    
    func updateFocusReminderTimer() {
        focusReminderTimer?.invalidate()
        focusReminderTimer = nil
        
        let isDetailed = UserDefaults.standard.bool(forKey: "focusDetailMode") && PermissionHelper.hasFullDiskAccess()
        guard enableFocus && enableFocusReminder && isDetailed && isFocusModeActive else {
            if isFocusReminder {
                isFocusReminder = false
            }
            return
        }
        
        let interval = TimeInterval(focusReminderInterval * 60)
        
        focusReminderTimer = Timer.scheduledTimerInCommonModes(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            // Re-verify conditions when timer fires
            let isDetailedMode = UserDefaults.standard.bool(forKey: "focusDetailMode") && PermissionHelper.hasFullDiskAccess()
            guard self.enableFocus && self.enableFocusReminder && isDetailedMode && self.isFocusModeActive else {
                self.isFocusReminder = false
                return
            }
            
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
                    self.scheduleOverlayHide(for: "focus")
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
    
    func cancelFocusReminderTimerForSleep() {
        focusReminderTimer?.invalidate()
        focusReminderTimer = nil
        if isFocusReminder {
            isFocusReminder = false
        }
    }
    
    func scheduleFocusReminderAfterWake() {
        focusReminderTimer?.invalidate()
        focusReminderTimer = nil
        if isFocusReminder {
            isFocusReminder = false
        }
        
        let isDetailed = UserDefaults.standard.bool(forKey: "focusDetailMode") && PermissionHelper.hasFullDiskAccess()
        guard enableFocus && enableFocusReminder && isDetailed && isFocusModeActive else { return }
        
        let interval = TimeInterval(focusReminderInterval * 60)
        focusReminderTimer = Timer.scheduledTimerInCommonModes(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.updateFocusReminderTimer()
        }
    }
    
    func silentlyUpdateFocusState(isActive: Bool, modeName: String, colorName: String = "systemIndigoColor", symbol: String = "moon.fill", details: ActiveFocusDetails? = nil) {
        let isDetailed = UserDefaults.standard.bool(forKey: "focusDetailMode") && PermissionHelper.hasFullDiskAccess()
        let finalName = isDetailed ? modeName : "Focus"
        let finalColor = isDetailed ? colorName : "systemIndigoColor"
        let finalSymbol = isDetailed ? symbol : "moon.fill"
        
        self.isFocusModeActive = isActive
        self.focusModeName = finalName
        self.focusColorName = finalColor
        self.focusSymbol = finalSymbol
        self.isFocusReminder = false
        self.isFocusSwitched = false
        
        if isActive {
            self.focusActiveDate = isDetailed ? (details?.startDate ?? self.focusActiveDate ?? Date()) : nil
            self.activeFocusDetails = isDetailed ? details : nil
            self.lastEndedFocusDetails = nil
            OverlayStateRelay.shared.lastActiveFocusModeName = finalName
            OverlayStateRelay.shared.lastActiveFocusSymbol = finalSymbol
        } else {
            if isDetailed {
                if var lastDetails = self.activeFocusDetails {
                    lastDetails.endedAt = Date()
                    self.lastEndedFocusDetails = lastDetails
                } else if var d = details {
                    d.endedAt = Date()
                    self.lastEndedFocusDetails = d
                } else if let start = self.focusActiveDate {
                    self.lastEndedFocusDetails = MediaKeyManager.ActiveFocusDetails(startDate: start, endedAt: Date(), endedReason: "turned off")
                }
            } else {
                self.lastEndedFocusDetails = nil
            }
            self.focusActiveDate = nil
            self.activeFocusDetails = nil
        }
        
        OverlayStateRelay.shared.displayedFocusModeActive = isActive
        OverlayStateRelay.shared.displayedFocusModeName = finalName
        OverlayStateRelay.shared.displayedFocusColorName = finalColor
        OverlayStateRelay.shared.displayedFocusSymbol = finalSymbol
        
        self.updateFocusReminderTimer()
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
                    self.cancelOverlayHide(for: "mic")
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
            self.cancelOverlayHide(for: "mic")
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
                    self.scheduleOverlayHide(for: "mic")
                }
                
                // Schedule next reminder instead of using repeats: true
                // This prevents runaway repeating timers from spamming right after Mac wakes up
                self.startMicMuteReminderTimer()
            }
            
            executeShow()
        }
    }
    
    func triggerFocusIndicator(isActive: Bool, modeName: String?, colorName: String = "systemIndigoColor", symbol: String = "moon.fill", isSwitched: Bool = false, details: ActiveFocusDetails? = nil) {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }

        // Notify NativeOverlayDismisser so it can disambiguate native empty banners
        NativeOverlayDismisser.shared.onSystemEvent(type: .focus)

        if !enableFocus {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isFocusModeActive = false
                self.updateFocusReminderTimer()
            }
            return
        }

        let shouldShowVisual = (isActive && notifyOnFocusOn) || (!isActive && notifyOnFocusOff)

        if shouldShowVisual {
            playNotificationSound(named: isActive ? soundOnFocusOn : soundOnFocusOff)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let now = Date()
            let timeSinceLastTrigger = now.timeIntervalSince(self.lastFocusTriggerTime)
            self.lastFocusTriggerTime = now
            
            let isDetailed = UserDefaults.standard.bool(forKey: "focusDetailMode") && PermissionHelper.hasFullDiskAccess()
            let finalName = isDetailed ? (modeName ?? "Focus") : "Focus"
            let finalColor = isDetailed ? colorName : "systemIndigoColor"
            let finalSymbol = isDetailed ? symbol : "moon.fill"
            
            // Always update internal runtime state so timers and flags stay 100% in sync
            self.isFocusModeActive = isActive
            self.focusModeName = finalName
            self.focusColorName = finalColor
            self.focusSymbol = finalSymbol
            if isActive {
                OverlayStateRelay.shared.lastActiveFocusModeName = finalName
                OverlayStateRelay.shared.lastActiveFocusSymbol = finalSymbol
            }
            self.isFocusReminder = false
            self.isFocusSwitched = isSwitched
            if isActive {
                self.focusActiveDate = isDetailed ? (details?.startDate ?? self.focusActiveDate ?? Date()) : nil
                self.activeFocusDetails = isDetailed ? details : nil
                self.lastEndedFocusDetails = nil
            } else {
                if isDetailed {
                    if var lastDetails = self.activeFocusDetails {
                        lastDetails.endedAt = Date()
                        self.lastEndedFocusDetails = lastDetails
                    } else if var d = details {
                        d.endedAt = Date()
                        self.lastEndedFocusDetails = d
                    } else if let start = self.focusActiveDate {
                        self.lastEndedFocusDetails = MediaKeyManager.ActiveFocusDetails(startDate: start, endedAt: Date(), endedReason: "turned off")
                    }
                } else {
                    self.lastEndedFocusDetails = nil
                }
                self.focusActiveDate = nil
                self.activeFocusDetails = nil
            }
            
            self.updateFocusReminderTimer()
            
            guard shouldShowVisual else {
                OverlayStateRelay.shared.displayedFocusModeActive = isActive
                OverlayStateRelay.shared.displayedFocusModeName = finalName
                OverlayStateRelay.shared.displayedFocusColorName = finalColor
                OverlayStateRelay.shared.displayedFocusSymbol = finalSymbol
                return
            }
            
            self.focusTimer?.invalidate()
            self.focusTransitionWorkItem?.cancel()
            self.focusTransitionWorkItem = nil
            
            let pos = self.getOverlayPosition(for: "focusOverlayPosition")
            self.dismissCollidingIndicators(newPosition: pos, source: "focus")
            
            let executeShow = { [weak self] in
                guard let self = self else { return }
                self.focusTransitionWorkItem = nil
                OverlayStateRelay.shared.displayedFocusModeActive = isActive
                OverlayStateRelay.shared.displayedFocusModeName = finalName
                OverlayStateRelay.shared.displayedFocusColorName = finalColor
                OverlayStateRelay.shared.displayedFocusSymbol = finalSymbol
                self.focusEventId = UUID()
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.showFocusIndicator = true
                    self.notifyOverlayStateChanged()
                    self.overlayTriggerTimes["focus"] = Date()
                }
                self.scheduleOverlayHide(for: "focus")
            }
            
            if self.showFocusIndicator {
                // If it was already visible and triggered recently (e.g. within 1.5s), update seamlessly in-place
                if timeSinceLastTrigger < 1.5 {
                    executeShow()
                } else {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self.showFocusIndicator = false
                    }
                    self.notifyOverlayStateChanged()
                    let workItem = DispatchWorkItem {
                        executeShow()
                    }
                    self.focusTransitionWorkItem = workItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
                }
            } else {
                executeShow()
            }
        }
    }
    
    func refreshFocusStatus() {
        focusObserver?.forcePollFocusStatus()
    }
    
    func handleNativeFocusBanner(allText: String, nestedIds: [String]) {
        let isDetailed = UserDefaults.standard.bool(forKey: "focusDetailMode") && PermissionHelper.hasFullDiskAccess()
        let lower = allText.lowercased()
        
        let isActive: Bool?
        if lower.contains(" | on | ") || lower.contains(" | on") || lower.hasSuffix(" on | ") || lower.hasSuffix(" on") || lower.contains(" | wł. | ") || lower.contains(" | wł.") || lower.contains("włączone") {
            isActive = true
        } else if lower.contains(" | off | ") || lower.contains(" | off") || lower.hasSuffix(" off | ") || lower.hasSuffix(" off") || lower.contains(" | wył. | ") || lower.contains(" | wył.") || lower.contains("wyłączone") {
            isActive = false
        } else {
            isActive = nil
        }
        
        guard let active = isActive else { return }
        
        var modeName: String
        let symbol: String
        let colorName: String
        
        if isDetailed {
            let parts = allText.components(separatedBy: " | ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            // Find candidate names excluding known status keywords
            let candidateNames = parts.filter { part in
                let pLower = part.lowercased()
                return pLower != "focus" &&
                       pLower != "on" &&
                       pLower != "off" &&
                       pLower != "wł." &&
                       pLower != "wył." &&
                       pLower != "włączone" &&
                       pLower != "wyłączone"
            }
            
            var rawModeName = self.focusModeName
            if let bestName = candidateNames.first(where: {
                let l = $0.lowercased()
                return l != "itunes u" && l != "itunes" && l != "bedtime" && l != "running" && l != "_gm"
            }) {
                rawModeName = bestName
            } else if let fallbackCandidate = candidateNames.first {
                let l = fallbackCandidate.lowercased()
                if l == "_gm" {
                    rawModeName = "Reduce Interruptions"
                } else if l == "itunes u" || l == "itunes" {
                    rawModeName = "Szkoła"
                } else if l == "bedtime" {
                    rawModeName = "Sleep"
                } else if l == "running" {
                    rawModeName = "Fitness"
                } else {
                    rawModeName = fallbackCandidate
                }
            }
            
            let isReduce = lower.contains("reduce interruptions") || lower.contains("redukuj") || lower.contains("zakłócenia") || nestedIds.contains("_gm") || rawModeName.lowercased() == "_gm" || rawModeName.lowercased() == "reduce interruptions"
            let isSleep = candidateNames.contains(where: { $0.lowercased() == "sleep" || $0.lowercased() == "sen" || $0.lowercased() == "bedtime" }) ||
                          lower.contains(" | sleep | ") || lower.contains(" | sen | ") || lower.contains(" | bedtime | ") ||
                          nestedIds.contains(where: { $0.contains("bed.double") })
            let isDND = candidateNames.contains(where: { $0.lowercased() == "do not disturb" || $0.lowercased() == "nie przeszkadzać" }) ||
                        lower.contains("do not disturb") || lower.contains("nie przeszkadzać")
            
            if isReduce {
                modeName = "Reduce Interruptions"
            } else if isSleep {
                modeName = "Sleep"
            } else if isDND {
                modeName = "Do Not Disturb"
            } else {
                modeName = rawModeName
            }
            
            // When turning OFF, ALWAYS preserve the previously active focus mode name if candidate name is generic or missing
            if !active {
                if modeName.isEmpty || modeName.lowercased() == "focus" || modeName.lowercased() == "_gm" {
                    let existingName = OverlayStateRelay.shared.lastActiveFocusModeName
                    let currentName = OverlayStateRelay.shared.focusModeName
                    if !existingName.isEmpty && existingName.lowercased() != "focus" && existingName.lowercased() != "_gm" {
                        modeName = existingName
                    } else if !currentName.isEmpty && currentName.lowercased() != "focus" && currentName.lowercased() != "_gm" {
                        modeName = currentName
                    } else {
                        modeName = "Focus"
                    }
                }
            }
            
            // Fix symbol detection:
            if isReduce {
                symbol = "apple.intelligence"
            } else if isSleep {
                symbol = "bed.double.fill"
            } else if let specificSymbol = nestedIds.first(where: { id in
                id.contains(".fill") || id.contains("moon") || id.contains("bed") || id.contains("person") ||
                id.contains("briefcase") || id.contains("book") || id.contains("figure.") || id.contains("graduationcap") || id.contains("apple.intelligence")
            }) {
                symbol = specificSymbol
            } else {
                let existingSymbol = OverlayStateRelay.shared.lastActiveFocusSymbol.isEmpty ? OverlayStateRelay.shared.focusSymbol : OverlayStateRelay.shared.lastActiveFocusSymbol
                if !active && !existingSymbol.isEmpty && existingSymbol != "moon.zzz" && existingSymbol != "moon.fill" && existingSymbol != "_gm" {
                    symbol = existingSymbol
                } else {
                    symbol = focusObserver?.getSymbol(for: modeName) ?? (active ? "moon.fill" : "moon.zzz")
                }
            }
            
            colorName = isReduce ? "reduceInterruptionsColor" : (focusObserver?.getColorName(for: modeName) ?? "systemIndigoColor")
        } else {
            modeName = "Focus"
            symbol = active ? "moon.fill" : "moon.zzz"
            colorName = "systemIndigoColor"
        }
        
        if active {
            OverlayStateRelay.shared.lastActiveFocusModeName = modeName
            OverlayStateRelay.shared.lastActiveFocusSymbol = symbol
        }
        
        focusObserver?.syncStateFromNativeBanner(isActive: active, modeName: modeName, colorName: colorName, symbol: symbol)
        let isSwitched = self.isFocusModeActive && active && modeName != self.focusModeName
        triggerFocusIndicator(isActive: active, modeName: modeName, colorName: colorName, symbol: symbol, isSwitched: isSwitched, details: isDetailed ? self.activeFocusDetails : nil)
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
                if !self.enablePrivacy || !self.notifyOnMicOn {
                    self.cancelOverlayHide(for: "mic")
                    if !self.isOverlayHoveredOrExpanded("mic") {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self.showMicIndicator = false
                        }
                    }
                    return
                }
                
                self.cancelOverlayHide(for: "mic")
                self.micEventId = UUID()
                
                if self.showMicIndicator && !self.isOverlayHoveredOrExpanded("mic") {
                    self.scheduleOverlayHide(for: "mic")
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
                self.cancelOverlayHide(for: "mic")
                if !self.isOverlayHoveredOrExpanded("mic") {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self.showMicIndicator = false
                    }
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
            
            self.cancelOverlayHide(for: "mic")
            let pos = self.getOverlayPosition(for: "micOverlayPosition")
            self.dismissCollidingIndicators(newPosition: pos, source: "mic")
            withAnimation(.easeInOut(duration: 0.15)) {
                self.micEventId = UUID()
                self.showMicIndicator = true
                self.overlayTriggerTimes["mic"] = Date()
                self.notifyOverlayStateChanged()
            }
            
            if !self.isOverlayHoveredOrExpanded("mic") {
                self.scheduleOverlayHide(for: "mic")
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
                if !self.enablePrivacy || !self.notifyOnCameraOn {
                    self.cancelOverlayHide(for: "camera")
                    if !self.isOverlayHoveredOrExpanded("camera") {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self.showCameraIndicator = false
                        }
                    }
                    return
                }
                
                self.cancelOverlayHide(for: "camera")
                self.cameraEventId = UUID()
                
                if self.showCameraIndicator && !self.isOverlayHoveredOrExpanded("camera") {
                    self.scheduleOverlayHide(for: "camera")
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
                self.cancelOverlayHide(for: "camera")
                if !self.isOverlayHoveredOrExpanded("camera") {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self.showCameraIndicator = false
                    }
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
            
            self.cancelOverlayHide(for: "camera")
            let pos = self.getOverlayPosition(for: "cameraOverlayPosition")
            self.dismissCollidingIndicators(newPosition: pos, source: "camera")
            withAnimation(.easeInOut(duration: 0.15)) {
                self.cameraEventId = UUID()
                self.showCameraIndicator = true
                self.overlayTriggerTimes["camera"] = Date()
                self.notifyOverlayStateChanged()
            }
            
            let camAllow = UserDefaults.standard.object(forKey: "cameraAllowExpansion") as? Bool ?? true
            if !camAllow { self.isCameraExpanded = false }
            
            if !self.isOverlayHoveredOrExpanded("camera") {
                self.scheduleOverlayHide(for: "camera")
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
            
            self.cancelOverlayHide(for: "location")
            let pos = self.getOverlayPosition(for: "locationOverlayPosition")
            self.dismissCollidingIndicators(newPosition: pos, source: "location")
            withAnimation(.easeInOut(duration: 0.15)) {
                self.locationEventId = UUID()
                self.showLocationIndicator = true
                self.overlayTriggerTimes["location"] = Date()
                self.notifyOverlayStateChanged()
            }
            
            if !self.isOverlayHoveredOrExpanded("location") {
                self.scheduleOverlayHide(for: "location")
            }
        }
    }
}
