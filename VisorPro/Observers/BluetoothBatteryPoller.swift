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
            
            if let connectedDevices = bluetoothItem["device_connected"] as? [[String: Any]] {
                for deviceDict in connectedDevices {
                    for (rawName, detailsRaw) in deviceDict {
                        let name = rawName.replacingOccurrences(of: "’", with: "'")
                        guard let details = detailsRaw as? [String: Any] else { continue }
                        
                        var extractedDetails: [String: String] = [:]
                        extractedDetails["SystemName"] = name
                        
                        let rawAddress = (details["device_address"] as? String) ?? name
                        let address = rawAddress.replacingOccurrences(of: "-", with: ":").uppercased()
                        if let addr = details["device_address"] as? String {
                            extractedDetails["MAC"] = addr.replacingOccurrences(of: "-", with: ":").uppercased()
                        }
                        if let rssi = details["device_rssi"] as? String { extractedDetails["RSSI"] = rssi + " dBm" }
                        if let type = details["device_minorType"] as? String { extractedDetails["Typ"] = type }
                        if let fw = details["device_firmwareVersion"] as? String { extractedDetails["Firmware"] = fw }
                        
                        self.manager?.updateBluetoothDetails(deviceName: address, details: extractedDetails)
                        
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
                        
                        if !currentBatteries.isEmpty {
                            for (component, bat) in currentBatteries {
                                processDevice(name: "\(name)\(component)", battery: bat)
                            }
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
            if name.hasSuffix("(Lewa)") {
                icon = "airpodpro.left"
            } else if name.hasSuffix("(Prawa)") {
                icon = "airpodpro.right"
            } else if name.hasSuffix("(Etui)") {
                icon = "airpodspro.chargingcase.wireless.fill"
            } else if name.lowercased().contains("mouse") || name.lowercased().contains("mysz") {
                icon = "magicmouse.fill"
            } else if name.lowercased().contains("keyboard") || name.lowercased().contains("klawiatura") {
                icon = "keyboard.fill"
            } else {
                icon = "headphones"
            }
            
            if self.manager?.peripheralIcons[name] == nil || self.manager?.peripheralIcons[name] == "bolt.batteryblock.fill" {
                self.manager?.peripheralIcons[name] = icon
            }
            
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
}
