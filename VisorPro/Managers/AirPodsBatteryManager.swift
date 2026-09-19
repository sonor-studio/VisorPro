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
    private var disconnectWorkItem: DispatchWorkItem?
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        // Clean up any orphaned log stream processes from previous app runs (e.g. after Xcode rebuilds)
        // Orphaned log streams can cause severe macOS Bluetooth and audio lag.
        let killTask = Process()
        killTask.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        killTask.arguments = ["-f", "subsystem == \"com.apple.bluetooth\" AND \\(eventMessage CONTAINS \"Components\""]
        try? killTask.run()
        killTask.waitUntilExit()
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.process = Process()
            self?.process?.executableURL = URL(fileURLWithPath: "/usr/bin/log")
            
            // Only fetch nearbyLidClosed for case open/close, and Batt C / Components / lidClosed for battery and in-ear status
            self?.process?.arguments = [
                "stream", 
                "--predicate", 
                "subsystem == \"com.apple.bluetooth\" AND (eventMessage CONTAINS \"Components\" OR eventMessage CONTAINS \"nearbyLidClosed\" OR eventMessage CONTAINS \"primaryInEar\" OR eventMessage CONTAINS \"secondaryInEar\" OR eventMessage CONTAINS \"Batt C\" OR eventMessage CONTAINS \"Setting inEarStateUnified\" OR eventMessage CONTAINS \"SmartRouting posting device\")"
            ]
            
            self?.pipe = Pipe()
            self?.process?.standardOutput = self?.pipe
            
            let errPipe = Pipe()
            self?.process?.standardError = errPipe
            
            let fileHandle = self?.pipe!.fileHandleForReading
            fileHandle?.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if data.isEmpty { return }
                if let str = String(data: data, encoding: .utf8) {
                    self?.processIncomingData(str)
                }
            }
            
            do {
                try self?.process?.run()
                print("AirPodsBatteryManager started monitoring.")
            } catch {
                print("Failed to start AirPodsBatteryManager: \(error)")
            }
        }
    }
    
    private func getCustomAirPodsName() -> String {
        var foundName = "AirPods"
        for (name, icon) in MediaKeyManager.shared.peripheralIcons {
            if icon.lowercased().contains("airpod") {
                foundName = name
                break
            }
        }
        if foundName == "AirPods" {
            for (name, _) in MediaKeyManager.shared.accessorySettings {
                if name.lowercased().contains("airpods") {
                    foundName = name
                    break
                }
            }
        }
        if foundName == "AirPods" {
            for entry in MediaKeyManager.shared.accessoryBatteryHistory {
                if entry.lowercased().contains("airpods") {
                    foundName = entry
                    break
                }
            }
        }
        return foundName
            .replacingOccurrences(of: " (Left)", with: "")
            .replacingOccurrences(of: " (Right)", with: "")
            .replacingOccurrences(of: " (Lewa)", with: "")
            .replacingOccurrences(of: " (Prawa)", with: "")
            .replacingOccurrences(of: " (Case)", with: "")
            .replacingOccurrences(of: " (Etui)", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    
    private func processIncomingData(_ text: String) {
        buffer += text
        while let range = buffer.range(of: "\n") {
            let line = String(buffer[..<range.lowerBound])
            buffer.removeSubrange(..<range.upperBound)
            
            // Check for in-ear state changes explicitly
            if line.contains("Setting inEarStateUnified") {
                if line.contains("-> InEar") {
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
    

    
    var lastLidOpenTime: Date = Date.distantPast
    var lastLidCloseTime: Date = Date.distantPast
    private var wantsBatteryOverlayFromLidOpen: Bool = false

    private func updateLidState(closed: Bool) {
        DispatchQueue.main.async {
            if self.isLidClosed != closed {
                self.isLidClosed = closed
                
                if closed {
                    self.lastLidCloseTime = Date()
                    MediaKeyManager.shared.dismissAirpodsGroupBatteryIndicator()
                } else {
                    self.lastLidOpenTime = Date()
                    self.wantsBatteryOverlayFromLidOpen = true
                }
            }
        }
    }
    
    func triggerOverlay() {
        MediaKeyManager.shared.triggerAirpodsGroupBatteryIndicator(deviceName: self.getCustomAirPodsName(), 
            leftBattery: OverlayStateRelay.shared.airpodsLeftBattery,
            leftCharging: OverlayStateRelay.shared.airpodsLeftCharging,
            rightBattery: OverlayStateRelay.shared.airpodsRightBattery,
            rightCharging: OverlayStateRelay.shared.airpodsRightCharging,
            caseBattery: OverlayStateRelay.shared.airpodsCaseBattery,
            caseCharging: OverlayStateRelay.shared.airpodsCaseCharging
        )
    }
    
    private func parseAudioAccessoryBatteryLine(_ line: String) {
        guard let range = line.range(of: "Batt ") else { return }
        let battStr = String(line[range.upperBound...]).components(separatedBy: ",").first ?? ""
        let parts = battStr.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        
        DispatchQueue.main.async {
            var startedCharging = false
            var didChangeValues = false
            for part in parts {
                if part.hasPrefix("L ") {
                    let valStr = part.dropFirst(2)
                    if let (sign, val) = self.parseSignAndValue(String(valStr)) {
                        let isCharging = (sign == "+")
                        if OverlayStateRelay.shared.airpodsLeftBattery != val || OverlayStateRelay.shared.airpodsLeftCharging != isCharging {
                            didChangeValues = true
                            if !OverlayStateRelay.shared.airpodsLeftCharging && isCharging { startedCharging = true }
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
                            if !OverlayStateRelay.shared.airpodsRightCharging && isCharging { startedCharging = true }
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
                            if !OverlayStateRelay.shared.airpodsCaseCharging && isCharging { startedCharging = true }
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
        let leftComp = extractComponent(name: "Left", from: line)
        let rightComp = extractComponent(name: "Right", from: line)
        let caseComp = extractComponent(name: "Case", from: line)
        
        DispatchQueue.main.async {
            var startedCharging = false
            var didChangeValues = false
            
            if let l = leftComp {
                let isCharging = (l.sign == "+")
                if OverlayStateRelay.shared.airpodsLeftBattery != l.value || OverlayStateRelay.shared.airpodsLeftCharging != isCharging {
                    didChangeValues = true
                    if !OverlayStateRelay.shared.airpodsLeftCharging && isCharging { startedCharging = true }
                    OverlayStateRelay.shared.airpodsLeftBattery = l.value
                    OverlayStateRelay.shared.airpodsLeftCharging = isCharging
                }
            }
            if let r = rightComp {
                let isCharging = (r.sign == "+")
                if OverlayStateRelay.shared.airpodsRightBattery != r.value || OverlayStateRelay.shared.airpodsRightCharging != isCharging {
                    didChangeValues = true
                    if !OverlayStateRelay.shared.airpodsRightCharging && isCharging { startedCharging = true }
                    OverlayStateRelay.shared.airpodsRightBattery = r.value
                    OverlayStateRelay.shared.airpodsRightCharging = isCharging
                }
            }
            if let c = caseComp {
                let isCharging = (c.sign == "+")
                if OverlayStateRelay.shared.airpodsCaseBattery != c.value || OverlayStateRelay.shared.airpodsCaseCharging != isCharging {
                    didChangeValues = true
                    if !OverlayStateRelay.shared.airpodsCaseCharging && isCharging { startedCharging = true }
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
    private func isAnyAirPodsConnectedToMac() -> Bool {
        guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return false }
        for device in devices {
            if device.isConnected() {
                if device.name?.lowercased().contains("airpods") == true || device.nameOrAddress.lowercased().contains("airpods") {
                    return true
                }
            }
        }
        return false
    }

    deinit {
        process?.terminate()
    }
}
