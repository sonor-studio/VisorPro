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
                self?.pollBluetooth()
            }
        }
        
        // Initial poll after 3 seconds
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.pollBluetooth()
        }
    }
    
    private func pollBluetooth() {
        guard let manager = self.manager else { return }
        
        let task = Process()
        task.launchPath = "/usr/sbin/system_profiler"
        task.arguments = ["SPBluetoothDataType"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return }
            
            parseBluetoothOutput(output)
        } catch {
        }
    }
    
    private func parseBluetoothOutput(_ output: String) {
        let lines = output.components(separatedBy: .newlines)
        
        var currentDevice: String?
        var inConnectedSection = false
        var currentBatteries: [String: Int] = [:]
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "Connected:" {
                inConnectedSection = true
                continue
            } else if trimmed == "Not Connected:" {
                inConnectedSection = false
                continue
            }
            
            if inConnectedSection {
                // Device name header
                if line.hasPrefix("          ") && !line.hasPrefix("              ") && line.hasSuffix(":") {
                    if let dev = currentDevice, !currentBatteries.isEmpty {
                        for (component, bat) in currentBatteries {
                            processDevice(name: "\(dev)\(component)", battery: bat)
                        }
                    }
                    
                    currentDevice = String(trimmed.dropLast())
                    currentBatteries = [:]
                } else if currentDevice != nil {
                    // Battery info
                    if trimmed.hasPrefix("Left Battery Level:") || trimmed.hasPrefix("Right Battery Level:") || trimmed.hasPrefix("Case Battery Level:") || trimmed.hasPrefix("Battery Level:") {
                        let components = trimmed.components(separatedBy: ":")
                        if components.count == 2 {
                            let valStr = components[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "%", with: "")
                            if let val = Int(valStr) {
                                if trimmed.hasPrefix("Left") {
                                    currentBatteries[" (Lewa)"] = val
                                } else if trimmed.hasPrefix("Right") {
                                    currentBatteries[" (Prawa)"] = val
                                } else if trimmed.hasPrefix("Case") {
                                    currentBatteries[" (Etui)"] = val
                                } else {
                                    currentBatteries[""] = val
                                }
                            }
                        }
                    }
                }
            }
        }
        
        if let dev = currentDevice, !currentBatteries.isEmpty {
            for (component, bat) in currentBatteries {
                processDevice(name: "\(dev)\(component)", battery: bat)
            }
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
            // so we assume isPluggedIn = false for simple wireless accessories (unless battery == 100).
            let isPluggedIn = (battery == 100) 
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
