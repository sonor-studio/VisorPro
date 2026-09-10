import Foundation
import SwiftUI
import AppKit

extension MediaKeyManager {
    
    func triggerLowBatteryWarning() {
        if !enableBattery { return }
        startFetchingTopBatteryConsumers()
        let currentLevel = currentBatteryPercentage
        playNotificationSound(named: currentLevel <= 10 ? soundOn10Percent : soundOn20Percent)
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

    func triggerAccessoryBatteryIndicator(deviceName: String, percentage: Int, isPluggedIn: Bool, isWarning: Bool) {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.accessoryBatteryLevels[deviceName] = percentage
            self.accessoryBatteryCharging[deviceName] = isPluggedIn
            
            if !self.enableAccessoryBattery { return }
            
            if !self.accessoryBatteryHistory.contains(deviceName) {
                self.accessoryBatteryHistory.append(deviceName)
            }
            if self.accessoryBatteryBlocklist.contains(deviceName) { return }
            
            self.accessoryBatteryDeviceName = deviceName
            self.accessoryBatteryPercentage = percentage
            self.accessoryBatteryIsPluggedIn = isPluggedIn
            self.accessoryBatteryIsWarning = isWarning
            
            if percentage == 100 {
                self.playNotificationSound(named: self.accessorySoundOn100Percent)
            } else if percentage <= 10 {
                self.playNotificationSound(named: self.accessorySoundOn10Percent)
            } else if percentage <= 20 {
                self.playNotificationSound(named: self.accessorySoundOn20Percent)
            }
            
            self.accessoryBatteryTimer?.invalidate()
            let pos = self.getOverlayPosition(for: "batteryOverlayPosition")
            self.dismissCollidingIndicators(newPosition: pos, source: "accessoryBattery")
            withAnimation(.easeInOut(duration: 0.15)) {
                self.accessoryBatteryEventId = UUID()
                self.showAccessoryBatteryIndicator = true
                self.notifyOverlayStateChanged()
                self.overlayTriggerTimes["accessoryBattery"] = Date()
            }
            
            let displayTime: TimeInterval = isWarning ? 4.5 : 3.5
            self.accessoryBatteryTimer = Timer.scheduledTimer(withTimeInterval: displayTime, repeats: false) { [weak self] _ in
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

}
