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
            volumeTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
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
            brightnessTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
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
        
        keyboardBrightnessTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
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

                self.capsLockTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in

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

                self.themeTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in

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

                self.languageTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in

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
                        
                        let executeShow = { [weak self] in
                            guard let self = self else { return }
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
}
