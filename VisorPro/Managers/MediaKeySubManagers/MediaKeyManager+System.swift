import Foundation
import AppKit
import CoreLocation
import AVFoundation
import SwiftUI

extension MediaKeyManager {
    func updateBatteryState(percentage: Int, pluggedIn: Bool, timeRemaining: String, cycleCount: Int = 0, healthPercentage: Int = 100, condition: String = "Normal", powerDraw: String = "0.0 W", isCharging: Bool = false) {
        if !enableBattery || isTestingBattery { return }
        let wasInitialized = self.isBatteryInitialized
        
        if pluggedIn && !self.isPluggedIn {
            self.initialPercentageWhenPluggedIn = percentage
            self.hasChargedSincePluggedIn = false
        } else if !pluggedIn {
            self.initialPercentageWhenPluggedIn = nil
            self.hasChargedSincePluggedIn = false
        }
        
        if pluggedIn, let initial = self.initialPercentageWhenPluggedIn, percentage > initial {
            self.hasChargedSincePluggedIn = true
        }
        
        if !wasInitialized && pluggedIn {
            self.hasChargedSincePluggedIn = true
        }
        
        let systemPriorLimit = self.readChargeLimit(currentCapacity: percentage)
        let isLimitReached = pluggedIn && !isCharging && percentage == systemPriorLimit && self.hasChargedSincePluggedIn
        
        var newLimit = 100
        if isLimitReached {
            newLimit = percentage
        }
        
        if self.chargeLimit != newLimit {
            self.chargeLimit = newLimit
        }
        
        let effectivelyFull = isLimitReached || (pluggedIn && !isCharging && percentage == 100)
        if self.isEffectivelyFullyCharged != effectivelyFull {
            self.isEffectivelyFullyCharged = effectivelyFull
        }
        
        if self.isPluggedIn != pluggedIn {
            self.isPluggedIn = pluggedIn
        }
        if self.currentBatteryPercentage != percentage {
            self.currentBatteryPercentage = percentage
        }
        self.batteryTimeRemaining = timeRemaining
        self.batteryCycleCount = cycleCount
        self.batteryHealthPercentage = healthPercentage
        self.batteryCondition = condition
        self.batteryPowerDraw = powerDraw
        if !wasInitialized {
            self.isBatteryInitialized = true
        }
    }

    func readChargeLimit(currentCapacity: Int = 0) -> Int {
        if let defaults = UserDefaults(suiteName: "com.apple.batteryui.charging.mac"),
           let limit = defaults.object(forKey: "com.apple.batteryui.charging.mac.prior.limit") as? Int,
           limit >= 50 && limit < 100 {
            return limit
        }
        return 100
    }

    func openBatterySettings() {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["x-apple.systempreferences:com.apple.Battery-Settings.extension"]
        task.launch()
    }

    func startFetchingTopBatteryConsumers() {
        fetchTopBatteryConsumers()
        topBatteryConsumersTimer?.invalidate()
        topBatteryConsumersTimer = Timer.scheduledTimerInCommonModes(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self, self.showLowBatteryWarning else {
                self?.topBatteryConsumersTimer?.invalidate()
                return
            }
            self.fetchTopBatteryConsumers()
        }
    }

    func getIconForProcess(name: String) -> NSImage? {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == name || $0.executableURL?.lastPathComponent == name }) {
            return app.icon
        }
        
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: name) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        
        let appsURL = URL(fileURLWithPath: "/Applications")
        if let enumerator = FileManager.default.enumerator(at: appsURL, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsPackageDescendants, .skipsHiddenFiles]),
           let file = enumerator.allObjects.first(where: { ($0 as? URL)?.lastPathComponent.lowercased() == "\(name.lowercased()).app" }) as? URL {
            return NSWorkspace.shared.icon(forFile: file.path)
        }
        
        return nil
    }

    func checkAccessibility() {

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        self.isTrusted = AXIsProcessTrustedWithOptions(options)
    }

    func syncPermissions() {
        if self.enableBluetooth && !PermissionHelper.checkBluetoothPermission() {
            self.enableBluetooth = false
        }
        
        let locStatus = PermissionHelper.sharedLocationManager.authorizationStatus
        if locStatus == .denied || locStatus == .restricted {
            if self.enableWiFi { self.enableWiFi = false }
            if self.notifyOnLocationOn { self.notifyOnLocationOn = false }
        }
        
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if micStatus != .authorized && micStatus != .notDetermined {
            if UserDefaults.standard.bool(forKey: "micShowVisualizer") {
                UserDefaults.standard.set(false, forKey: "micShowVisualizer")
            }
        }
    }

}
