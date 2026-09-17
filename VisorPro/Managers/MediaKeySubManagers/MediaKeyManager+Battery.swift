import Foundation
import SwiftUI
import AppKit

extension MediaKeyManager {
    
    func triggerBatteryThresholdWarning(percentage: Int, sound: String) {
        if !enableBattery { return }
        startFetchingTopBatteryConsumers()
        playNotificationSound(named: sound)
        let battPos = self.getOverlayPosition(for: "batteryOverlayPosition")
        dismissCollidingIndicators(newPosition: battPos, source: "battery")
        
        let wasActive = showChargingStatus || showLowBatteryWarning || showUnpluggedStatus
        if wasActive {
            withAnimation(.easeInOut(duration: 0.25)) {
                showChargingStatus = false
                showLowBatteryWarning = false
                showUnpluggedStatus = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.showLowBatteryWarning = true; self.overlayTriggerTimes["battery_warning"] = Date()
                    self.notifyOverlayStateChanged()
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.25)) { self.showLowBatteryWarning = true; self.overlayTriggerTimes["battery_warning"] = Date() }
            self.notifyOverlayStateChanged()
        }
        
        chargingTimer?.invalidate()
        batteryTimer?.invalidate()
        batteryTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
            self?.hideBatteryOverlay()
        }
    }

    func triggerChargingStatus() {
        if !enableBattery { return }
        if isPluggedIn {
            playNotificationSound(named: soundOnPlug)
        } else if currentBatteryPercentage >= 100 {
            playNotificationSound(named: soundOn100Percent)
        }
        chargingTimer?.invalidate()
        batteryTimer?.invalidate()
        let battPos = self.getOverlayPosition(for: "batteryOverlayPosition")
        dismissCollidingIndicators(newPosition: battPos, source: "battery")
        
        let wasActive = showChargingStatus || showLowBatteryWarning || showUnpluggedStatus
        if wasActive {
            withAnimation(.easeInOut(duration: 0.25)) {
                showChargingStatus = false
                showLowBatteryWarning = false
                showUnpluggedStatus = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.showChargingStatus = true; self.overlayTriggerTimes["battery_charging"] = Date()
                    self.notifyOverlayStateChanged()
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                self.showChargingStatus = true; self.overlayTriggerTimes["battery_charging"] = Date()
                self.notifyOverlayStateChanged()
            }
        }
        
        chargingTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
            self?.hideBatteryOverlay()
        }
    }

    func triggerAccessoryBatteryIndicator(deviceName: String, percentage: Int, isPluggedIn: Bool, isWarning: Bool, customSound: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard self.enableBluetooth else { return }
            
            self.accessoryBatteryLevels[deviceName] = percentage
            self.accessoryBatteryCharging[deviceName] = isPluggedIn
            
            let baseName: String = {
                if deviceName.hasSuffix(" (Left)") { return String(deviceName.dropLast(7)) }
                if deviceName.hasSuffix(" (Right)") { return String(deviceName.dropLast(8)) }
                if deviceName.hasSuffix(" (Case)") { return String(deviceName.dropLast(7)) }
                return deviceName
            }()
            
            let settings = self.accessorySettings[baseName] ?? AccessoryDeviceSettings()
            if !settings.enableOverlay { return }
            
            if !self.accessoryBatteryHistory.contains(deviceName) {
                self.accessoryBatteryHistory.append(deviceName)
            }
            if self.accessoryBatteryBlocklist.contains(deviceName) { return }
            
            let isVisible = self.showAccessoryBatteryIndicator
            let currentBase: String = {
                if self.accessoryBatteryDeviceName.hasSuffix(" (Left & Right)") { return String(self.accessoryBatteryDeviceName.dropLast(15)) }
                if self.accessoryBatteryDeviceName.hasSuffix(" (Left)") { return String(self.accessoryBatteryDeviceName.dropLast(7)) }
                if self.accessoryBatteryDeviceName.hasSuffix(" (Right)") { return String(self.accessoryBatteryDeviceName.dropLast(8)) }
                if self.accessoryBatteryDeviceName.hasSuffix(" (Case)") { return String(self.accessoryBatteryDeviceName.dropLast(7)) }
                return self.accessoryBatteryDeviceName
            }()
            
            if isVisible && currentBase == baseName && self.accessoryBatteryPercentage == percentage {
                let isCurrentLeft = self.accessoryBatteryDeviceName.hasSuffix(" (Left)")
                let isCurrentRight = self.accessoryBatteryDeviceName.hasSuffix(" (Right)")
                let isNewLeft = deviceName.hasSuffix(" (Left)")
                let isNewRight = deviceName.hasSuffix(" (Right)")
                
                if (isCurrentLeft && isNewRight) || (isCurrentRight && isNewLeft) {
                    self.accessoryBatteryDeviceName = baseName + " (Left & Right)"
                } else if self.accessoryBatteryDeviceName != deviceName && !self.accessoryBatteryDeviceName.hasSuffix(" (Left & Right)") {
                    self.accessoryBatteryDeviceName = deviceName
                }
            } else {
                self.accessoryBatteryDeviceName = deviceName
            }
            
            self.accessoryBatteryPercentage = percentage
            self.accessoryBatteryIsPluggedIn = isPluggedIn
            self.accessoryBatteryIsWarning = isWarning
            
            if let sound = customSound {
                self.playNotificationSound(named: sound)
            }
            
            self.notificationTimers["accessoryBattery"]?.invalidate()
            let pos = self.getOverlayPosition(for: "batteryOverlayPosition")
            self.dismissCollidingIndicators(newPosition: pos, source: "accessoryBattery")
            withAnimation(.easeInOut(duration: 0.15)) {
                self.accessoryBatteryEventId = UUID()
                self.showAccessoryBatteryIndicator = true
                self.notifyOverlayStateChanged()
                self.overlayTriggerTimes["accessoryBattery"] = Date()
            }
            
            let displayTime: TimeInterval = isWarning ? 4.5 : 3.5
            self.notificationTimers["accessoryBattery"] = Timer.scheduledTimer(withTimeInterval: displayTime, repeats: false) { [weak self] _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    self?.showAccessoryBatteryIndicator = false
                }
            }
        }
    }

    func fetchTopBatteryConsumers() {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/top")
            task.arguments = ["-l", "2", "-n", "8", "-stats", "command,power", "-o", "power"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    self.parseTopOutput(output)
                }
            } catch {
                LogManager.shared.log("Error in MediaKeyManager.swift: \(error)", level: "ERROR")
            }
        }
    }

    func dismissAirpodsGroupBatteryIndicator() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.showAirpodsGroupBatteryIndicator {
                self.cancelOverlayHide(for: "airpodsGroupBattery")
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.showAirpodsGroupBatteryIndicator = false
                    self.notifyOverlayStateChanged()
                }
            }
        }
    }
    
    func triggerAirpodsGroupBatteryIndicator(deviceName: String = "AirPods", leftBattery: Int, leftCharging: Bool, rightBattery: Int, rightCharging: Bool, caseBattery: Int, caseCharging: Bool) {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }
        if !self.enableBluetooth { return }
        
        let settings = accessorySettings[deviceName] ?? AccessoryDeviceSettings()
        if !settings.enableOverlay || !settings.notifyOnCaseOpen { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            OverlayStateRelay.shared.airpodsDeviceName = deviceName
            OverlayStateRelay.shared.airpodsLeftBattery = leftBattery
            OverlayStateRelay.shared.airpodsLeftCharging = leftCharging
            OverlayStateRelay.shared.airpodsRightBattery = rightBattery
            OverlayStateRelay.shared.airpodsRightCharging = rightCharging
            OverlayStateRelay.shared.airpodsCaseBattery = caseBattery
            OverlayStateRelay.shared.airpodsCaseCharging = caseCharging
            
            let wasVisible = self.showAirpodsGroupBatteryIndicator
            
            if !wasVisible {
                self.cancelOverlayHide(for: "airpodsGroupBattery")
                if !settings.soundOnCaseOpen.isEmpty {
                    self.playNotificationSound(named: settings.soundOnCaseOpen)
                }
            }
            let pos = self.getOverlayPosition(for: "batteryOverlayPosition")
            self.dismissCollidingIndicators(newPosition: pos, source: "airpodsGroupBattery")
            
            withAnimation(.easeInOut(duration: 0.15)) {
                if !wasVisible {
                    self.airpodsGroupBatteryEventId = UUID()
                    OverlayStateRelay.shared.airpodsGroupBatteryTimerId = UUID()
                }
                self.showAirpodsGroupBatteryIndicator = true
                self.notifyOverlayStateChanged()
                if !wasVisible {
                    self.overlayTriggerTimes["airpodsGroupBattery"] = Date()
                }
            }
        }
    }

}
