import Foundation

class BluetoothBatteryPoller {
    private weak var manager: MediaKeyManager?
    private var timer: Timer?
    private var lastLevels: [String: Int] = [:]
    
    init(manager: MediaKeyManager) {
        self.manager = manager
        startPolling()
    }
    
    func startPolling() {
        // Poll every 30 seconds to avoid high CPU usage
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            DispatchQueue.global(qos: .background).async {
                self?.forcePoll()
            }
        }
        
        // Initial poll after 3 seconds
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.forcePoll()
        }
    }
    
    func forcePoll() {
        guard self.manager != nil else { return }
        
        let task = Process()
        task.launchPath = "/usr/sbin/system_profiler"
        task.arguments = ["SPBluetoothDataType", "-xml"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            parseBluetoothXML(data)
        } catch {
        }
    }
    
    private func parseBluetoothXML(_ data: Data) {
        do {
            guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [[String: Any]],
                  let firstItem = plist.first,
                  let items = firstItem["_items"] as? [[String: Any]],
                  let bluetoothItem = items.first else {
                return
            }
            
            var allDevices: [[String: Any]] = []
            if let connected = bluetoothItem["device_connected"] as? [[String: Any]] {
                allDevices.append(contentsOf: connected)
            }
            if let notConnected = bluetoothItem["device_not_connected"] as? [[String: Any]] {
                allDevices.append(contentsOf: notConnected)
            }
            
            if !allDevices.isEmpty {
                var seenMACs = Set<String>()
                var currentPollNames = Set<String>()
                
                for deviceDict in allDevices {
                    for (rawName, detailsRaw) in deviceDict {
                        let name = rawName.replacingOccurrences(of: "\u{2019}", with: "'")
                        guard let details = detailsRaw as? [String: Any] else { continue }
                        
                        // Deduplicate by MAC address — system_profiler sometimes returns the same
                        // device twice under different names (e.g. "AirPods Pro" and "User's AirPods Pro")
                        let rawAddress = (details["device_address"] as? String) ?? ""
                        let address = rawAddress.replacingOccurrences(of: "-", with: ":").uppercased()
                        if !address.isEmpty {
                            if seenMACs.contains(address) { continue }
                            seenMACs.insert(address)
                        }
                        
                        var extractedDetails: [String: String] = [:]
                        extractedDetails["SystemName"] = name
                        
                        if !address.isEmpty {
                            extractedDetails["MAC"] = address
                        }
                        if let rssi = details["device_rssi"] as? String { extractedDetails["RSSI"] = rssi + " dBm" }
                        if let type = details["device_minorType"] as? String { extractedDetails["Typ"] = type }
                        if let fw = details["device_firmwareVersion"] as? String { extractedDetails["Firmware"] = fw }
                        
                        self.manager?.updateBluetoothDetails(deviceName: address.isEmpty ? name : address, details: extractedDetails)
                        
                        var currentBatteries: [String: Int] = [:]
                        for (k, v) in details {
                            guard let valStr = v as? String else { continue }
                            let lowerK = k.lowercased()
                            if lowerK.contains("battery") {
                                if let val = Int(valStr.replacingOccurrences(of: "%", with: "")) {
                                    if lowerK.contains("left") {
                                        currentBatteries[" (Left)"] = val
                                    } else if lowerK.contains("right") {
                                        currentBatteries[" (Right)"] = val
                                    } else if lowerK.contains("case") {
                                        currentBatteries[" (Case)"] = val
                                    } else {
                                        currentBatteries[""] = val
                                    }
                                }
                            }
                        }
                        
                        // If we have component-specific batteries (Left/Right/Case), drop the generic
                        // entry to avoid a standalone "AirPods Pro" alongside the component entries
                        let hasComponents = currentBatteries.keys.contains(where: { !$0.isEmpty })
                        if hasComponents {
                            currentBatteries.removeValue(forKey: "")
                        }
                        
                        if !currentBatteries.isEmpty {
                            for (component, bat) in currentBatteries {
                                let fullName = "\(name)\(component)"
                                currentPollNames.insert(fullName)
                                processDevice(name: fullName, battery: bat)
                            }
                        }
                    }
                }
                
                // Clean up stale duplicates from history: if a baseName has entries in the
                // current poll, remove any history entries with the same baseName that
                // weren't seen in this poll (e.g. old "AirPods Pro" when only components exist now)
                if !currentPollNames.isEmpty {
                    let currentBaseNames = Set(currentPollNames.map { Self.baseName(for: $0) })
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.manager?.accessoryBatteryHistory.removeAll { entry in
                            let entryBase = Self.baseName(for: entry)
                            return currentBaseNames.contains(entryBase) && !currentPollNames.contains(entry)
                        }
                    }
                }
            }
        } catch {
        }
    }
    
    private func processDevice(name: String, battery: Int) {
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Dopasowanie ikon
            let icon: String
            if name.hasSuffix("(Left)") {
                icon = "airpodpro.left"
            } else if name.hasSuffix("(Right)") {
                icon = "airpodpro.right"
            } else if name.hasSuffix("(Case)") {
                icon = "airpodspro.chargingcase.wireless.fill"
            } else if name.lowercased().contains("mouse") || name.lowercased().contains("mysz") {
                icon = "magicmouse.fill"
            } else if name.lowercased().contains("keyboard") || name.lowercased().contains("klawiatura") {
                icon = "keyboard.fill"
            } else if name.lowercased().contains("trackpad") {
                icon = "magicmouse.fill"
            } else {
                icon = "headphones"
            }
            
            self.manager?.peripheralIcons[name] = icon
            
            // Note: system_profiler doesn't easily tell us if it's currently plugged in/charging
            // so we assume isPluggedIn = false for simple wireless accessories.
            // Previously we checked if battery == 100, but that causes false charging states for fully charged headphones.
            let isPluggedIn = false
            self.manager?.updateAccessoryState(deviceName: name, percentage: battery, isPluggedIn: isPluggedIn)
            
            let lastBat = self.lastLevels[name]
            
            if let lastBat = lastBat {
                let justDroppedTo20 = (lastBat > 20 && battery <= 20)
                let justDroppedTo10 = (lastBat > 10 && battery <= 10)
                let justHit100 = (lastBat < 100 && battery == 100)
                
                if justDroppedTo20 || justDroppedTo10 || justHit100 {
                    let isWarning = justDroppedTo20 || justDroppedTo10
                    
                    if (justDroppedTo20 && self.manager?.notifyOn20Percent == true) ||
                       (justDroppedTo10 && self.manager?.notifyOn10Percent == true) ||
                       (justHit100 && self.manager?.notifyOn100Percent == true) {
                        
                        self.manager?.triggerAccessoryBatteryIndicator(deviceName: name, percentage: battery, isPluggedIn: isPluggedIn, isWarning: isWarning)
                    }
                }
            }
            
            self.lastLevels[name] = battery
        }
    }
    
    private static func baseName(for deviceName: String) -> String {
        if deviceName.hasSuffix(" (Left)") { return String(deviceName.dropLast(7)) }
        if deviceName.hasSuffix(" (Right)") { return String(deviceName.dropLast(8)) }
        if deviceName.hasSuffix(" (Case)") { return String(deviceName.dropLast(7)) }
        return deviceName
    }
}
