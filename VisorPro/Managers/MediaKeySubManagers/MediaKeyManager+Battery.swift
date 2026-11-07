import Foundation
import SwiftUI
import AppKit

extension MediaKeyManager {
    
    func triggerBatteryThresholdWarning(percentage: Int, sound: String) {
        if !enableBattery { return }
        startFetchingTopBatteryConsumers()
        playNotificationSound(named: sound)
        
        chargingTimer?.invalidate()
        batteryTimer?.invalidate()
        batteryTransitionWorkItem?.cancel()
        batteryTransitionWorkItem = nil
        
        let battPos = self.getOverlayPosition(for: "batteryOverlayPosition")
        dismissCollidingIndicators(newPosition: battPos, source: "battery")
        
        let wasActive = showChargingStatus || showLowBatteryWarning || showUnpluggedStatus
        let executeShow = { [weak self] in
            guard let self = self else { return }
            self.batteryTransitionWorkItem = nil
            OverlayStateRelay.shared.batteryOverlayMode = .warning
            withAnimation(.easeInOut(duration: 0.25)) {
                self.showLowBatteryWarning = true
                self.overlayTriggerTimes["battery_warning"] = Date()
                self.notifyOverlayStateChanged()
            }
            self.scheduleOverlayHide(for: "battery")
        }
        
        if wasActive {
            withAnimation(.easeInOut(duration: 0.25)) {
                self.showChargingStatus = false
                self.showLowBatteryWarning = false
                self.showUnpluggedStatus = false
            }
            self.notifyOverlayStateChanged()
            let workItem = DispatchWorkItem {
                executeShow()
            }
            self.batteryTransitionWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
        } else {
            executeShow()
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
        batteryTransitionWorkItem?.cancel()
        batteryTransitionWorkItem = nil

        let battPos = self.getOverlayPosition(for: "batteryOverlayPosition")
        dismissCollidingIndicators(newPosition: battPos, source: "battery")
        
        let wasActive = showChargingStatus || showLowBatteryWarning || showUnpluggedStatus
        let executeShow = { [weak self] in
            guard let self = self else { return }
            self.batteryTransitionWorkItem = nil
            OverlayStateRelay.shared.batteryOverlayMode = .charging
            withAnimation(.easeInOut(duration: 0.25)) {
                self.showChargingStatus = true
                self.overlayTriggerTimes["battery_charging"] = Date()
                self.notifyOverlayStateChanged()
            }
            self.scheduleOverlayHide(for: "battery")
        }
        
        if wasActive {
            withAnimation(.easeInOut(duration: 0.25)) {
                self.showChargingStatus = false
                self.showLowBatteryWarning = false
                self.showUnpluggedStatus = false
            }
            self.notifyOverlayStateChanged()
            let workItem = DispatchWorkItem {
                executeShow()
            }
            self.batteryTransitionWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
        } else {
            executeShow()
        }
    }

    func triggerUnplugStatus() {
        if !enableBattery { return }
        playNotificationSound(named: soundOnUnplug)
        
        chargingTimer?.invalidate()
        batteryTimer?.invalidate()
        batteryTransitionWorkItem?.cancel()
        batteryTransitionWorkItem = nil

        let battPos = self.getOverlayPosition(for: "batteryOverlayPosition")
        dismissCollidingIndicators(newPosition: battPos, source: "battery")
        
        let wasActive = showChargingStatus || showLowBatteryWarning || showUnpluggedStatus
        let executeShow = { [weak self] in
            guard let self = self else { return }
            self.batteryTransitionWorkItem = nil
            OverlayStateRelay.shared.batteryOverlayMode = .unplugged
            withAnimation(.easeInOut(duration: 0.25)) {
                self.showUnpluggedStatus = true
                self.overlayTriggerTimes["battery_unplugged"] = Date()
                self.notifyOverlayStateChanged()
            }
            self.scheduleOverlayHide(for: "battery")
        }
        
        if wasActive {
            withAnimation(.easeInOut(duration: 0.25)) {
                self.showChargingStatus = false
                self.showLowBatteryWarning = false
                self.showUnpluggedStatus = false
            }
            self.notifyOverlayStateChanged()
            let workItem = DispatchWorkItem {
                executeShow()
            }
            self.batteryTransitionWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
        } else {
            executeShow()
        }
    }

    func triggerAccessoryBatteryIndicator(deviceName: String, percentage: Int, isPluggedIn: Bool, isWarning: Bool, isIncreasing: Bool = false, customSound: String? = nil) {
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
            OverlayStateRelay.shared.accessoryBatteryIsIncreasing = isIncreasing
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
                let isCurrentLeftRight = self.accessoryBatteryDeviceName.hasSuffix(" (Left & Right)")
                let isNewLeft = deviceName.hasSuffix(" (Left)")
                let isNewRight = deviceName.hasSuffix(" (Right)")
                let isNewCase = deviceName.hasSuffix(" (Case)")
                let isCurrentCase = self.accessoryBatteryDeviceName.hasSuffix(" (Case)")
                
                // Never merge Case with earbuds — Case always gets its own overlay
                if isNewCase && (isCurrentLeft || isCurrentRight || isCurrentLeftRight) {
                    // Case arrived while earbuds are showing — replace with Case
                    self.accessoryBatteryDeviceName = deviceName
                } else if (isNewLeft || isNewRight) && isCurrentCase {
                    // Earbud arrived while Case is showing — replace with earbud
                    self.accessoryBatteryDeviceName = deviceName
                } else if (isCurrentLeft && isNewRight) || (isCurrentRight && isNewLeft) {
                    // Merge Left + Right earbuds only
                    self.accessoryBatteryDeviceName = baseName + " (Left & Right)"
                } else if self.accessoryBatteryDeviceName != deviceName && !isCurrentLeftRight {
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
            self.scheduleOverlayHide(for: "accessoryBattery", delay: displayTime)
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
            }
        }
    }

    func dismissAirpodsGroupBatteryIndicator() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.showAirpodsGroupBatteryIndicator {
                self.cancelOverlayHide(for: "airpodsGroupBattery")
                self.showAirpodsGroupBatteryIndicator = false
                AirPodsBatteryManager.shared.handleOverlayDismissed()
                self.notifyOverlayStateChanged()
            }
        }
    }
    
    func triggerAirpodsGroupBatteryIndicator(deviceName: String = "AirPods", leftBattery: Int, leftCharging: Bool, rightBattery: Int, rightCharging: Bool, caseBattery: Int, caseCharging: Bool) {
        self.lastConnectionEventTime = Date()
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }
        if !self.enableBluetooth { return }
        
        let settings = airPodsSettings(for: deviceName)
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
            
            // Prevent dual overlay collision: dismiss single-item accessory battery or duplicate Bluetooth notifications for AirPods
            self.showAccessoryBatteryIndicator = false
            self.activeBluetoothNotifications.removeAll { $0.deviceName.lowercased().contains("airpod") || $0.id.contains("AIRPODS") }
            self.activePeripheralNotifications.removeAll { $0.deviceName.lowercased().contains("airpod") }
            
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
            
            // Schedule auto-hide timer if behavior is set to auto-hide
            if settings.caseOpenBehavior != "persistent" {
                self.scheduleOverlayHide(for: "airpodsGroupBattery")
            } else {
                self.cancelOverlayHide(for: "airpodsGroupBattery")
            }
        }
    }

}
