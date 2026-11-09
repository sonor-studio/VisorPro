import Foundation
import Combine
import SwiftUI
import IOBluetooth

class AirPodsBatteryManager: ObservableObject {
    static let shared = AirPodsBatteryManager()
    
    private var process: Process?
    private var pipe: Pipe?
    private var buffer = ""
    // Track state to prevent continuous re-triggering
    private var isLidClosed: Bool = true
    var isAnyInEar: Bool = false
    var lastConnectionLogTime: Date = Date.distantPast
    var lastInEarEventTime: Date = Date.distantPast
    var lastLidOpenTime: Date = Date.distantPast
    var lastLidCloseTime: Date = Date.distantPast
    private var wantsBatteryOverlayFromLidOpen: Bool = false
    private var lastOverlayTriggerTime: Date = Date.distantPast
    private var lastBatteryUpdateTime: Date = Date.distantPast
    private var validationTimer: Timer?
    private var disconnectWorkItem: DispatchWorkItem?
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        // Clean up any orphaned log stream processes from previous app runs (e.g. after Xcode rebuilds)
        // Orphaned log streams can cause severe macOS Bluetooth and audio lag.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let killTask = Process()
            killTask.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            killTask.arguments = ["-f", "subsystem == \"com.apple.bluetooth\" AND \\(eventMessage CONTAINS \"Components\""]
            try? killTask.run()
            killTask.waitUntilExit()
            
            self?.launchLogStream()
        }
    }
    
    private func launchLogStream() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            self.process = Process()
            self.process?.executableURL = URL(fileURLWithPath: "/usr/bin/log")
            
            // Only fetch nearbyLidClosed for case open/close, and Batt C / Components / lidClosed for battery and in-ear status
            self.process?.arguments = [
                "stream", 
                "--predicate", 
                "subsystem == \"com.apple.bluetooth\" AND (eventMessage CONTAINS \"Components\" OR eventMessage CONTAINS \"nearbyLidClosed\" OR eventMessage CONTAINS \"primaryInEar\" OR eventMessage CONTAINS \"secondaryInEar\" OR eventMessage CONTAINS \"Batt C\" OR eventMessage CONTAINS \"Setting inEarStateUnified\" OR eventMessage CONTAINS \"SmartRouting posting device\")"
            ]
            
            self.pipe = Pipe()
            self.process?.standardOutput = self.pipe
            
            let errPipe = Pipe()
            self.process?.standardError = errPipe
            
            let fileHandle = self.pipe!.fileHandleForReading
            fileHandle.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if data.isEmpty { return }
                if let str = String(data: data, encoding: .utf8) {
                    self?.processIncomingData(str)
                }
            }
            
            do {
                try self.process?.run()
            } catch {
            }
        }
    }
    
    func getCustomAirPodsName() -> String {
        for (name, _) in MediaKeyManager.shared.accessorySettings {
            let lower = name.lowercased()
            if lower.contains("airpod") && !lower.contains("left") && !lower.contains("right") && !lower.contains("case") {
                return name
            }
        }
        if let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] {
            for device in devices {
                guard let name = device.name ?? device.nameOrAddress else { continue }
                let lower = name.lowercased()
                if lower.contains("airpod") {
                    return name
                }
            }
        }
        for (name, icon) in MediaKeyManager.shared.peripheralIcons {
            if icon.lowercased().contains("airpod") && name != "AirPods" {
                return name
            }
        }
        return OverlayStateRelay.shared.airpodsDeviceName.isEmpty ? "AirPods" : OverlayStateRelay.shared.airpodsDeviceName
    }
    
    private func processIncomingData(_ text: String) {
        buffer += text
        while let range = buffer.range(of: "\n") {
            let line = String(buffer[..<range.lowerBound])
            buffer.removeSubrange(..<range.upperBound)
            
            if line.contains("SmartRouting posting device") {
                lastConnectionLogTime = Date()
            }
            
            // Check for in-ear state changes explicitly
            if line.contains("Setting inEarStateUnified") {
                lastInEarEventTime = Date()
                if line.contains("-> InEar") {
                    lastConnectionLogTime = Date()
                    if !isAnyInEar {
                        isAnyInEar = true
                        MediaKeyManager.shared.dismissAirpodsGroupBatteryIndicator()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            if self.isAnyAirPodsConnectedToMac() {
                                // Fallback: if native banner doesn't show (e.g. physical connect via BT menu), this will trigger it.
                                // If native banner DOES show, NativeOverlayDismisser triggers first and bluetoothConnectionStateByDevice ignores this one.
                                MediaKeyManager.shared.triggerBluetoothIndicator(deviceName: self.getCustomAirPodsName(), deviceAddress: "AIRPODS_CONNECTION", isConnected: true)
                            }
                        }
                    }
                } else if line.contains("InEar ->") {
                    isAnyInEar = false
                    MediaKeyManager.shared.triggerBluetoothIndicator(deviceName: self.getCustomAirPodsName(), deviceAddress: "AIRPODS_CONNECTION", isConnected: false)
                }
            }
            
            // Check for explicit lid state transitions
            if line.contains("nearbyLidClosed") {
                if line.contains("yes -> no") {
                    updateLidState(closed: false)
                } else if line.contains("no -> yes") {
                    updateLidState(closed: true)
                }
            }
            
            // Check for explicit battery transitions
            if line.contains("Batt C") {
                parseAudioAccessoryBatteryLine(line)
            } else if line.contains("Components") {
                parseComponentsLine(line)
            }
        }
    }
    

    
    func hasPairedAirPods() -> Bool {
        if let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] {
            for device in devices {
                let name = (device.name ?? device.nameOrAddress ?? "").lowercased()
                if name.contains("airpod") || name.contains("beats") {
                    return true
                }
            }
        }
        for (name, _) in MediaKeyManager.shared.accessorySettings {
            if name.lowercased().contains("airpod") {
                return true
            }
        }
        for (name, icon) in MediaKeyManager.shared.peripheralIcons {
            if icon.lowercased().contains("airpod") || name.lowercased().contains("airpod") {
                return true
            }
        }
        return false
    }

    private func updateLidState(closed: Bool) {
        guard hasPairedAirPods() else { return }
        
        DispatchQueue.main.async {
            self.isLidClosed = closed
            
            if closed {
                self.lastLidCloseTime = Date()
                self.wantsBatteryOverlayFromLidOpen = false
                self.dismissOverlay()
            } else {
                self.lastLidOpenTime = Date()
                self.wantsBatteryOverlayFromLidOpen = true
            }
        }
    }
    
    func startValidationTimer() {
        stopValidationTimer()
        validationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.performOverlayValidation()
        }
    }
    
    func stopValidationTimer() {
        validationTimer?.invalidate()
        validationTimer = nil
    }
    
    private func performOverlayValidation() {
        guard OverlayStateRelay.shared.showAirpodsGroupBatteryIndicator else {
            stopValidationTimer()
            return
        }
        
        let isHovered = MediaKeyManager.shared.isOverlayHoveredOrExpanded("airpodsGroupBattery")
        if isHovered {
            return
        }
        
        let now = Date()
        let timeSinceTrigger = now.timeIntervalSince(lastOverlayTriggerTime)
        let timeSinceLidOpen = now.timeIntervalSince(lastLidOpenTime)
        
        // 1. If user has no paired AirPods on this Mac, dismiss immediately
        if !hasPairedAirPods() {
            dismissOverlay()
            return
        }
        
        // 2. If lid explicitly closed or in-ear state active, dismiss immediately
        if isLidClosed || isAnyInEar {
            dismissOverlay()
            return
        }
        
        // 3. If user disabled case open notifications in accessory settings, dismiss immediately
        let settings = MediaKeyManager.shared.airPodsSettings(for: getCustomAirPodsName())
        if !settings.enableOverlay || !settings.notifyOnCaseOpen {
            dismissOverlay()
            return
        }
        
        // 4. Auto-dismiss timeout (if configured to auto-hide after delay):
        if settings.caseOpenBehavior != "persistent" {
            let duration = MediaKeyManager.notificationDuration
            if timeSinceTrigger >= duration || timeSinceLidOpen >= duration {
                dismissOverlay()
                return
            }
        }
    }
    
    func prepareForTestTrigger() {
        isLidClosed = false
        isAnyInEar = false
        let now = Date()
        lastOverlayTriggerTime = now
        lastLidOpenTime = now
        lastBatteryUpdateTime = now
        OverlayStateRelay.shared.airpodsDeviceName = self.getCustomAirPodsName()
        startValidationTimer()
    }
    
    func handleOverlayDismissed() {
        stopValidationTimer()
        self.isLidClosed = true
        self.wantsBatteryOverlayFromLidOpen = false
    }

    func dismissOverlay() {
        handleOverlayDismissed()
        MediaKeyManager.shared.dismissAirpodsGroupBatteryIndicator()
    }
    
    func triggerOverlay() {
        guard hasPairedAirPods() else { return }
        
        let now = Date()
        if now.timeIntervalSince(lastOverlayTriggerTime) < 1.0 {
            return
        }
        lastOverlayTriggerTime = now
        lastBatteryUpdateTime = now
        lastLidOpenTime = now
        isLidClosed = false
        isAnyInEar = false
        wantsBatteryOverlayFromLidOpen = false
        
        let customName = self.getCustomAirPodsName()
        OverlayStateRelay.shared.airpodsDeviceName = customName
        
        let left = OverlayStateRelay.shared.airpodsLeftBattery
        let right = OverlayStateRelay.shared.airpodsRightBattery
        let caseBat = OverlayStateRelay.shared.airpodsCaseBattery
        guard left > 0 || right > 0 || caseBat > 0 else { return }
        
        MediaKeyManager.shared.triggerAirpodsGroupBatteryIndicator(
            deviceName: customName, 
            leftBattery: left,
            leftCharging: OverlayStateRelay.shared.airpodsLeftCharging,
            rightBattery: right,
            rightCharging: OverlayStateRelay.shared.airpodsRightCharging,
            caseBattery: caseBat,
            caseCharging: OverlayStateRelay.shared.airpodsCaseCharging
        )
        
        startValidationTimer()
    }
    
    private func parseAudioAccessoryBatteryLine(_ line: String) {
        guard hasPairedAirPods() else { return }
        guard let range = line.range(of: "Batt ") else { return }
        let battStr = String(line[range.upperBound...]).components(separatedBy: ",").first ?? ""
        let parts = battStr.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        
        DispatchQueue.main.async {
            self.lastBatteryUpdateTime = Date()
            var didChangeValues = false
            for part in parts {
                if part.hasPrefix("L ") {
                    let valStr = part.dropFirst(2)
                    if let (sign, val) = self.parseSignAndValue(String(valStr)) {
                        let isCharging = (sign == "+")
                        if OverlayStateRelay.shared.airpodsLeftBattery != val || OverlayStateRelay.shared.airpodsLeftCharging != isCharging {
                            didChangeValues = true
                            
                            OverlayStateRelay.shared.airpodsLeftBattery = val
                            OverlayStateRelay.shared.airpodsLeftCharging = isCharging
                            MediaKeyManager.shared.btPoller?.processDevice(name: self.getCustomAirPodsName() + " (Left)", battery: val, forcePluggedIn: isCharging)
                        }
                    }
                } else if part.hasPrefix("R ") {
                    let valStr = part.dropFirst(2)
                    if let (sign, val) = self.parseSignAndValue(String(valStr)) {
                        let isCharging = (sign == "+")
                        if OverlayStateRelay.shared.airpodsRightBattery != val || OverlayStateRelay.shared.airpodsRightCharging != isCharging {
                            didChangeValues = true
                            
                            OverlayStateRelay.shared.airpodsRightBattery = val
                            OverlayStateRelay.shared.airpodsRightCharging = isCharging
                            MediaKeyManager.shared.btPoller?.processDevice(name: self.getCustomAirPodsName() + " (Right)", battery: val, forcePluggedIn: isCharging)
                        }
                    }
                } else if part.hasPrefix("C ") {
                    let valStr = part.dropFirst(2)
                    if let (sign, val) = self.parseSignAndValue(String(valStr)) {
                        let isCharging = (sign == "+")
                        if OverlayStateRelay.shared.airpodsCaseBattery != val || OverlayStateRelay.shared.airpodsCaseCharging != isCharging {
                            didChangeValues = true
                            
                            OverlayStateRelay.shared.airpodsCaseBattery = val
                            OverlayStateRelay.shared.airpodsCaseCharging = isCharging
                            MediaKeyManager.shared.btPoller?.processDevice(name: self.getCustomAirPodsName() + " (Case)", battery: val, forcePluggedIn: isCharging)
                        }
                    }
                }
            }
            
            let shouldShow = self.wantsBatteryOverlayFromLidOpen && Date().timeIntervalSince(self.lastLidOpenTime) < 5.0
            
            if self.wantsBatteryOverlayFromLidOpen {
                self.wantsBatteryOverlayFromLidOpen = false
                if shouldShow && !self.isLidClosed && !self.isAnyInEar {
                    self.triggerOverlay()
                }
            } else if didChangeValues {
                if !self.isLidClosed && !self.isAnyInEar && OverlayStateRelay.shared.showAirpodsGroupBatteryIndicator {
                    self.triggerOverlay()
                }
            }
        }
    }
    
    private func parseSignAndValue(_ str: String) -> (String, Int)? {
        let clean = str.replacingOccurrences(of: "%", with: "")
        guard clean.count >= 2 else { return nil }
        let sign = String(clean.prefix(1))
        let valStr = String(clean.dropFirst())
        if let val = Int(valStr) {
            return (sign, val)
        }
        return nil
    }

    private func extractComponent(name: String, from line: String) -> (sign: String, value: Int)? {
        let pattern = "\(name) ([+-]?)(\\d+)%"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            let sign = (line as NSString).substring(with: match.range(at: 1))
            let valStr = (line as NSString).substring(with: match.range(at: 2))
            if let val = Int(valStr) {
                return (sign, val)
            }
        }
        return nil
    }
    
    private func parseComponentsLine(_ line: String) {
        guard hasPairedAirPods() else { return }
        let leftComp = extractComponent(name: "Left", from: line)
        let rightComp = extractComponent(name: "Right", from: line)
        let caseComp = extractComponent(name: "Case", from: line)
        
        DispatchQueue.main.async {
            self.lastBatteryUpdateTime = Date()
            var didChangeValues = false
            
            if let l = leftComp {
                let isCharging = (l.sign == "+")
                if OverlayStateRelay.shared.airpodsLeftBattery != l.value || OverlayStateRelay.shared.airpodsLeftCharging != isCharging {
                    didChangeValues = true
                    
                    OverlayStateRelay.shared.airpodsLeftBattery = l.value
                    OverlayStateRelay.shared.airpodsLeftCharging = isCharging
                }
            }
            if let r = rightComp {
                let isCharging = (r.sign == "+")
                if OverlayStateRelay.shared.airpodsRightBattery != r.value || OverlayStateRelay.shared.airpodsRightCharging != isCharging {
                    didChangeValues = true
                    
                    OverlayStateRelay.shared.airpodsRightBattery = r.value
                    OverlayStateRelay.shared.airpodsRightCharging = isCharging
                }
            }
            if let c = caseComp {
                let isCharging = (c.sign == "+")
                if OverlayStateRelay.shared.airpodsCaseBattery != c.value || OverlayStateRelay.shared.airpodsCaseCharging != isCharging {
                    didChangeValues = true
                    
                    OverlayStateRelay.shared.airpodsCaseBattery = c.value
                    OverlayStateRelay.shared.airpodsCaseCharging = isCharging
                }
            }
            
            let shouldShow = self.wantsBatteryOverlayFromLidOpen && Date().timeIntervalSince(self.lastLidOpenTime) < 5.0
            
            if self.wantsBatteryOverlayFromLidOpen {
                self.wantsBatteryOverlayFromLidOpen = false
                if shouldShow && !self.isLidClosed && !self.isAnyInEar {
                    self.triggerOverlay()
                }
            } else if didChangeValues {
                if !self.isLidClosed && !self.isAnyInEar && OverlayStateRelay.shared.showAirpodsGroupBatteryIndicator {
                    self.triggerOverlay()
                }
            }
        }
    }

    func isAnyAirPodsConnectedToMac() -> Bool {
        guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return false }
        for device in devices {
            if device.isConnected() {
                let name = (device.name ?? device.nameOrAddress ?? "").lowercased()
                if name.contains("airpod") || name.contains("beats") {
                    return true
                }
                for (settingName, _) in MediaKeyManager.shared.accessorySettings {
                    if settingName.lowercased().contains("airpod") && name.contains(settingName.lowercased()) {
                        return true
                    }
                }
                for (iconName, icon) in MediaKeyManager.shared.peripheralIcons {
                    if icon.lowercased().contains("airpod") && name.contains(iconName.lowercased()) {
                        return true
                    }
                }
            }
        }
        return false
    }

    deinit {
        stopValidationTimer()
        process?.terminate()
    }
}
