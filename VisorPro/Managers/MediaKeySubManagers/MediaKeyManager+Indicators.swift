import SwiftUI
import AppKit

extension MediaKeyManager {
    func triggerVolumeIndicator(playSound: Bool = false) {
        if !enableVolume { return }
        if playSound {
            playNotificationSound(named: soundOnVolume)
        }

        cancelOverlayHide(for: "volume")
        volumeTimer?.invalidate()
        let volPos = self.getOverlayPosition(for: "volumeOverlayPosition")
        dismissCollidingIndicators(newPosition: volPos, source: "volume")
        
        if !showVolumeIndicator {
            withAnimation(.easeInOut(duration: 0.25)) {
                showVolumeIndicator = true
                notifyOverlayStateChanged()
            }
        }
        self.overlayTriggerTimes["volume"] = Date()
        
        if !globalHoveredTypes.contains("volume") {
            volumeTimer = Timer.scheduledTimerInCommonModes(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    self?.showVolumeIndicator = false
                }
            }
        }
    }

    func triggerBrightnessIndicator(playSound: Bool = false) {
        if !enableBrightness { return }
        if playSound {
            playNotificationSound(named: soundOnBrightness)
        }
        cancelOverlayHide(for: "brightness")
        brightnessTimer?.invalidate()
        let brightPos = self.getOverlayPosition(for: "brightnessOverlayPosition")
        dismissCollidingIndicators(newPosition: brightPos, source: "brightness")
        
        if !showBrightnessIndicator {
            withAnimation(.easeInOut(duration: 0.25)) {
                showBrightnessIndicator = true
                notifyOverlayStateChanged()
            }
        }
        self.overlayTriggerTimes["brightness"] = Date()
        
        if !globalHoveredTypes.contains("brightness") {
            brightnessTimer = Timer.scheduledTimerInCommonModes(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    self?.showBrightnessIndicator = false
                }
            }
        }
    }

    func triggerKeyboardBrightnessIndicator(playSound: Bool = false) {
        if !enableKeyboardBrightness { return }
        if playSound {
            playNotificationSound(named: soundOnKeyboardBrightness)
        }
        cancelOverlayHide(for: "keyboardBrightness")
        keyboardBrightnessTimer?.invalidate()
        let kbPos = self.getOverlayPosition(for: "keyboardBrightnessOverlayPosition")
        dismissCollidingIndicators(newPosition: kbPos, source: "keyboardBrightness")
        
        if !showKeyboardBrightnessIndicator {
            withAnimation(.easeInOut(duration: 0.25)) {
                showKeyboardBrightnessIndicator = true
                notifyOverlayStateChanged()
            }
        }
        self.overlayTriggerTimes["keyboardBrightness"] = Date()
        
        keyboardBrightnessTimer = Timer.scheduledTimerInCommonModes(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                self?.showKeyboardBrightnessIndicator = false
            }
        }
    }

    func triggerCapsLockIndicator(isOn: Bool) {
        if !enableKeyboard { return }
        if isOn && !notifyOnCapsLockOn { return }
        if !isOn && !notifyOnCapsLockOff { return }
        
        let sound = isOn ? soundOnCapsLock : soundOnCapsLockOff
        if sound != "None" {
            playNotificationSound(named: sound)
        }
        
        capsLockTimer?.invalidate()
        let pos = self.getOverlayPosition(for: "capsLockOverlayPosition")
        dismissCollidingIndicators(newPosition: pos, source: "capsLock")
        
        self.isCapsLockOn = isOn
            let executeShow = { [weak self] in
                guard let self = self else { return }

                self.capsLockEventId = UUID()

                withAnimation(.easeInOut(duration: 0.15)) {

                    self.showCapsLockIndicator = true; self.overlayTriggerTimes["capsLock"] = Date()
                    self.notifyOverlayStateChanged()

                }

                self.capsLockTimer = Timer.scheduledTimerInCommonModes(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in

                    withAnimation(.easeInOut(duration: 0.25)) {

                        self?.showCapsLockIndicator = false

                    }

                }

            }

            

            executeShow()
    }

    func triggerThemeIndicator(isDark: Bool) {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }

        if !enableTheme { return }
        if isDark && !notifyOnThemeDark { return }
        if !isDark && !notifyOnThemeLight { return }
        
        playNotificationSound(named: isDark ? soundOnThemeDark : soundOnThemeLight)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.themeTimer?.invalidate()
            
            let pos = self.getOverlayPosition(for: "themeOverlayPosition")
            self.dismissCollidingIndicators(newPosition: pos, source: "theme")
            
            self.isDarkMode = isDark
            let executeShow = { [weak self] in
                guard let self = self else { return }

                self.themeEventId = UUID()

                withAnimation(.easeInOut(duration: 0.15)) {

                    self.showThemeIndicator = true; self.overlayTriggerTimes["theme"] = Date()
                    self.notifyOverlayStateChanged()

                }

                self.themeTimer = Timer.scheduledTimerInCommonModes(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in

                    withAnimation(.easeInOut(duration: 0.25)) {

                        self?.showThemeIndicator = false

                    }

                }

            }

            

            if self.showThemeIndicator {

                withAnimation(.easeInOut(duration: 0.25)) {

                    self.showThemeIndicator = false

                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {

                    executeShow()

                }

            } else {

                executeShow()

            }
        }
    }

    func triggerLanguageIndicator(language: String) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.triggerLanguageIndicator(language: language)
            }
            return
        }
        if !enableKeyboard { return }
        if !notifyOnLanguageChange { return }
        
        playNotificationSound(named: soundOnLanguageChange)
        
        languageTimer?.invalidate()
        let pos = self.getOverlayPosition(for: "languageOverlayPosition")
        dismissCollidingIndicators(newPosition: pos, source: "language")
        
        self.currentKeyboardLanguage = language
            let executeShow = { [weak self] in
                guard let self = self else { return }

                self.languageEventId = UUID()

                withAnimation(.easeInOut(duration: 0.15)) {

                    self.showLanguageIndicator = true; self.overlayTriggerTimes["language"] = Date()
                    self.notifyOverlayStateChanged()

                }

                self.languageTimer = Timer.scheduledTimerInCommonModes(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in

                    withAnimation(.easeInOut(duration: 0.25)) {

                        self?.showLanguageIndicator = false

                    }

                }

            }

            

            if self.showLanguageIndicator {

                withAnimation(.easeInOut(duration: 0.25)) {

                    self.showLanguageIndicator = false

                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {

                    executeShow()

                }

            } else {

                executeShow()

            }
    }

    func triggerRamOverlay() {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }

        if !notifyOnHighRam { return }
        
        playNotificationSound(named: self.soundOnHighRam)
        
        self.hideRamIndicatorTask?.cancel()
        let pos = self.getOverlayPosition(for: "ramOverlayPosition")
        dismissCollidingIndicators(newPosition: pos, source: "ram")
        
        let executeShow = { [weak self] in
            guard let self = self else { return }
            self.ramEventId = UUID()
            withAnimation(.easeInOut(duration: 0.15)) {
                self.showRamIndicator = true
                self.notifyOverlayStateChanged()
                self.overlayTriggerTimes["ram"] = Date()
            }
            
                            self.scheduleOverlayHide(for: "cpu")
        }
        
        if self.showRamIndicator {
            withAnimation(.easeInOut(duration: 0.1)) {
                self.showRamIndicator = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                executeShow()
            }
        } else {
            executeShow()
        }
    }

    func triggerTrashOverlay(isManualTrigger: Bool = false) {
        if !showTrashModule { return }
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }

        if !isManualTrigger && !notifyOnTrashFull { return }
        
        if !isManualTrigger {
            playNotificationSound(named: self.soundOnTrashFull)
        }
        
        self.hideTrashIndicatorTask?.cancel()
        let pos = self.getOverlayPosition(for: "trashOverlayPosition")
        dismissCollidingIndicators(newPosition: pos, source: "trash")
        
        let executeShow = { [weak self] in
            guard let self = self else { return }
            self.trashEventId = UUID()
            withAnimation(.easeInOut(duration: 0.15)) {
                self.showTrashIndicator = true
                self.notifyOverlayStateChanged()
                self.overlayTriggerTimes["trash"] = Date()
            }
            self.scheduleOverlayHide(for: "trash")
        }
        
        if self.showTrashIndicator {
            withAnimation(.easeInOut(duration: 0.1)) {
                self.showTrashIndicator = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                executeShow()
            }
        } else {
            executeShow()
        }
    }

    
    func triggerCpuTempOverlay(temp: Double) {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }

        DispatchQueue.main.async {
            self.cpuTemperature = temp
            self.cpuTempHistory.removeFirst()
            self.cpuTempHistory.append(temp)
            
            let threshold = self.highCpuTempThreshold
            
            if temp >= threshold {
                if !self.cpuAlertTriggered {
                    self.cpuAlertTriggered = true
                    
                    if self.notifyOnHighCpuTemp && !self.globalHoveredTypes.contains("cpu") {
                        self.playNotificationSound(named: self.soundOnHighCpuTemp)
                        
                        self.cancelOverlayHide(for: "cpu")
                        let pos = self.getOverlayPosition(for: "cpuOverlayPosition")
                        self.dismissCollidingIndicators(newPosition: pos, source: "cpu")
                        
                        let executeShow = { 

                            self.cpuEventId = UUID()
                            withAnimation(.easeInOut(duration: 0.15)) {
                                self.showCpuIndicator = true
                                self.overlayTriggerTimes["cpu"] = Date()
                                self.notifyOverlayStateChanged()
                            }
                            
                            self.scheduleOverlayHide(for: "cpu")
                        }
                        
                        if self.showCpuIndicator {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                self.showCpuIndicator = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: executeShow)
                        } else {
                            executeShow()
                        }
                    }
                }
            } else if temp <= (threshold - 5.0) {
                self.cpuAlertTriggered = false
            }
        }
    }
    
    // MARK: - AirPods Mode
    func triggerAirPodsModeOverlayFromNativeTrigger() {
        if let mode = self.airPodsModeObserver?.getCurrentMode() {
            self.triggerAirPodsModeOverlay(mode: mode)
        }
    }
    
    func triggerAirPodsModeOverlay(mode: Int, showOverlay: Bool = true) {
        if !enableBluetooth { return }
        
        let changed = (OverlayStateRelay.shared.airPodsModeValue != mode)
        if changed {
            OverlayStateRelay.shared.previousAirPodsModeValue = OverlayStateRelay.shared.airPodsModeValue
        }
        
        var shouldShow = true
        if mode == 1 { shouldShow = false } // Never show for Off
        if mode == 2 && !notifyOnAirPodsANC { shouldShow = false }
        if mode == 4 && !notifyOnAirPodsAdaptive { shouldShow = false }
        if mode == 3 && !notifyOnAirPodsTransparency { shouldShow = false }
        
        // Sounds for listening modes are handled by AirPods themselves
        
        let isHovering = globalHoveredTypes.contains("airpodsMode") || actualHoveredTypes.contains("airpodsMode")
        
        // External change while visible
        if showAirPodsModeIndicator && changed && !isHovering {
            withAnimation(.easeInOut(duration: 0.2)) {
                OverlayStateRelay.shared.showAirPodsModeIndicator = false
            }
            
            if !shouldShow {
                OverlayStateRelay.shared.airPodsModeValue = mode
                return
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                OverlayStateRelay.shared.airPodsModeValue = mode
                OverlayStateRelay.shared.airPodsModeEventId = UUID()
                OverlayStateRelay.shared.showAirPodsModeIndicator = true
                self.overlayTriggerTimes["airpodsMode"] = Date()
                self.scheduleOverlayHide(for: "airpodsMode")
            }
            return
        }
        
        // If we shouldn't show it and it wasn't an external change while visible
        if !shouldShow {
            OverlayStateRelay.shared.airPodsModeValue = mode
            return 
        }
        
        OverlayStateRelay.shared.airPodsModeValue = mode
        OverlayStateRelay.shared.airPodsModeEventId = UUID()
        
        guard showOverlay else { return }
        
        // Ensure they are mutually exclusive: hide AirPods Connection overlays if Mode overlay appears
        withAnimation(.easeInOut(duration: 0.15)) {
            self.activeBluetoothNotifications.removeAll { $0.id == "AIRPODS_CONNECTION" || $0.deviceName.lowercased().contains("airpods") }
            self.notifyOverlayStateChanged()
        }
        
        if showAirPodsModeIndicator {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                // Animation triggers timeout progress bar reset
            }
        } else {
            OverlayStateRelay.shared.showAirPodsModeIndicator = true
        }
        
        self.overlayTriggerTimes["airpodsMode"] = Date()
        self.scheduleOverlayHide(for: "airpodsMode")
    }

    func showLastViewedOverlay() {
        guard let last = self.overlayTriggerTimes.max(by: { $0.value < $1.value }) else { return }
        let overlayId = last.key
        
        let relay = OverlayStateRelay.shared
        
        switch overlayId {
        case "volume": triggerVolumeIndicator(playSound: false)
        case "brightness": triggerBrightnessIndicator(playSound: false)
        case "keyboardBrightness": triggerKeyboardBrightnessIndicator(playSound: false)
        case "battery_charging", "battery_warning", "battery": 
            if relay.showLowBatteryWarning || !relay.isPluggedIn {
                triggerBatteryThresholdWarning(percentage: relay.currentBatteryPercentage, sound: "None")
            } else {
                triggerChargingStatus()
            }
        case "capsLock": triggerCapsLockIndicator(isOn: self.isCapsLockOn)
        case "theme": triggerThemeIndicator(isDark: self.isDarkMode)
        case "language": triggerLanguageIndicator(language: self.currentKeyboardLanguage)
        case "ram": triggerRamOverlay()
        case "trash": triggerTrashOverlay(isManualTrigger: true)
        case "cpu": triggerCpuTempOverlay(temp: self.cpuTemperature)
        case "mic": triggerMicIndicator(isActive: relay.isMicActive)
        case "camera": triggerCameraIndicator(isActive: relay.isCameraActive)
        case "location": triggerLocationIndicator()
        case "date": triggerDateIndicator()
        case "wifi": triggerWiFiIndicator(ssid: relay.wiFiSSID, isConnected: relay.wiFiIsConnected)
        case "copy", "cut", "paste": 
            withAnimation(.easeInOut(duration: 0.15)) {
                self.showCopyIndicator = true
                self.overlayTriggerTimes["copy"] = Date()
                self.notifyOverlayStateChanged()
            }
            self.scheduleOverlayHide(for: "copy")
        case "accessoryBattery":
            triggerAccessoryBatteryIndicator(
                deviceName: relay.accessoryBatteryDeviceName,
                percentage: relay.accessoryBatteryPercentage,
                isPluggedIn: relay.accessoryBatteryIsPluggedIn,
                isWarning: relay.accessoryBatteryIsWarning,
                isIncreasing: relay.accessoryBatteryIsIncreasing
            )
        case "airpodsGroupBattery":
            triggerAirpodsGroupBatteryIndicator(
                deviceName: relay.airpodsDeviceName,
                leftBattery: relay.airpodsLeftBattery,
                leftCharging: relay.airpodsLeftCharging,
                rightBattery: relay.airpodsRightBattery,
                rightCharging: relay.airpodsRightCharging,
                caseBattery: relay.airpodsCaseBattery,
                caseCharging: relay.airpodsCaseCharging
            )
        default:
            if overlayId.hasPrefix("bluetooth_") || overlayId.hasPrefix("peripheral_") || overlayId.hasPrefix("display_") {
                if let notif = relay.notificationHistory[overlayId] {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if overlayId.hasPrefix("bluetooth_") {
                            if !self.activeBluetoothNotifications.contains(where: { $0.id == notif.id }) { self.activeBluetoothNotifications.append(notif) }
                        } else if overlayId.hasPrefix("peripheral_") {
                            if !self.activePeripheralNotifications.contains(where: { $0.id == notif.id }) { self.activePeripheralNotifications.append(notif) }
                        } else if overlayId.hasPrefix("display_") {
                            if !self.activeDisplayNotifications.contains(where: { $0.id == notif.id }) { self.activeDisplayNotifications.append(notif) }
                        }
                        self.overlayTriggerTimes[overlayId] = Date()
                        self.notifyOverlayStateChanged()
                    }
                    self.scheduleOverlayHide(for: overlayId)
                }
            } else if overlayId == "media" {
                withAnimation(.easeInOut) { self.showMediaIndicator = true }
                self.overlayTriggerTimes["media"] = Date(); self.notifyOverlayStateChanged()
                self.scheduleOverlayHide(for: "media")
            } else if overlayId == "smartRouting" {
                withAnimation(.easeInOut) { relay.showSmartRoutingIndicator = true }
                self.overlayTriggerTimes["smartRouting"] = Date(); self.notifyOverlayStateChanged()
                self.scheduleOverlayHide(for: "smartRouting")
            }
            break
        }
    }
}

