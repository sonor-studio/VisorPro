import Foundation
import IOKit.ps

class BatteryObserver {
    private weak var manager: MediaKeyManager?
    private var runLoopSource: Unmanaged<CFRunLoopSource>?
    
    private var lastChargingState: [String: Bool] = [:]
    private var lastCapacity: [String: Int] = [:]
    private var smoothedAmperage: Double?
    
    init(manager: MediaKeyManager) {
        self.manager = manager
        startObserving()
        checkBatteryState(initial: true)
    }
    
    func startObserving() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        
        let callback: @convention(c) (UnsafeMutableRawPointer?) -> Void = { context in
            guard let context = context else { return }
            let observer = Unmanaged<BatteryObserver>.fromOpaque(context).takeUnretainedValue()
            observer.checkBatteryState(initial: false)
        }
        
        runLoopSource = IOPSNotificationCreateRunLoopSource(callback, context)
        
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source.takeUnretainedValue(), .defaultMode)
        }
    }
    
    func refresh() {
        updateLivePowerDraw()
    }
    
    private func getBatteryDescriptionFast() -> [String: Any]? {
        let matchingDict = IOServiceMatching("AppleSmartBattery")
        let service = IOServiceGetMatchingService(0, matchingDict)
        
        if service != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess {
                let dict = props?.takeRetainedValue() as? [String: Any]
                IOObjectRelease(service)
                return dict
            }
            IOObjectRelease(service)
        }
        return nil
    }
    
    private func updateLivePowerDraw() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var powerDrawStr = self.manager?.batteryPowerDraw ?? "0.0 W"
            
            if let battery = self.getBatteryDescriptionFast() {
                let voltage = battery["Voltage"] as? Double ?? (battery["AppleRawBatteryVoltage"] as? Double ?? 0.0)
                var amperage = 0.0
                if let ampNumber = battery["Amperage"] as? NSNumber {
                    amperage = Double(Int64(bitPattern: ampNumber.uint64Value))
                }
                if amperage == 0.0, let instAmpNumber = battery["InstantAmperage"] as? NSNumber {
                    amperage = Double(Int64(bitPattern: instAmpNumber.uint64Value))
                }
                
                let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
                let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as Array
                var isChargingSys = false
                for source in sources {
                    if let desc = IOPSGetPowerSourceDescription(info, source).takeUnretainedValue() as? [String: Any] {
                        if let isCharging = desc[kIOPSIsChargingKey] as? Bool {
                            isChargingSys = isCharging
                        }
                    }
                }
                
                if voltage > 0 && amperage != 0 {
                    let watts = abs((voltage / 1000.0) * (amperage / 1000.0))
                    let prefix = isChargingSys ? "+" : "-"
                    powerDrawStr = String(format: "%@%.1f W", prefix, watts)
                } else {
                    if let adapter = battery["AdapterDetails"] as? [String: Any], let adapterWatts = adapter["Watts"] as? NSNumber {
                        powerDrawStr = "AC \(adapterWatts.intValue)W"
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.manager?.batteryPowerDraw = powerDrawStr
            }
        }
    }
    
    private func checkBatteryState(initial: Bool) {
        guard let manager = manager else { return }
        
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as Array
        
        for source in sources {
            if let description = IOPSGetPowerSourceDescription(info, source).takeUnretainedValue() as? [String: Any] {
                let name = description[kIOPSNameKey] as? String ?? "Unknown Battery"
                let type = description[kIOPSTypeKey] as? String ?? ""
                let state = description[kIOPSPowerSourceStateKey] as? String ?? ""
                let isPluggedIn = (state == kIOPSACPowerValue)
                let capacity = description[kIOPSCurrentCapacityKey] as? Int ?? -1
                
                
                if type == kIOPSInternalBatteryType {
                    if !initial && !manager.useSystemOSD {
                        if let lastState = lastChargingState["InternalBattery"], lastState != isPluggedIn {
                            DispatchQueue.main.async {
                                manager.lastAction = isPluggedIn ? "Power connected ⚡️" : "Power disconnected 🔋"
                            }
                        }
                        
                        if let lastCap = lastCapacity["InternalBattery"], lastCap != capacity {
                            if let target = Int(manager.targetBatteryPercentage) {
                                if capacity == target {
                                    DispatchQueue.main.async {
                                        manager.lastAction = "Battery reached \(target)%!"
                                    }
                                }
                            }
                        }
                    }
                    
                    let sysTimeToEmpty = description[kIOPSTimeToEmptyKey] as? Int ?? -1
                    let sysTimeToFull = description[kIOPSTimeToFullChargeKey] as? Int ?? -1
                    
                    DispatchQueue.global(qos: .userInitiated).async {
                        var timeStr = "Calculating..."
                        let isChargingSys = description[kIOPSIsChargingKey] as? Bool ?? false
                        
                        if isPluggedIn {
                            if sysTimeToFull > 0 && sysTimeToFull < 10000 {
                                let hours = sysTimeToFull / 60
                                let minutes = sysTimeToFull % 60
                                timeStr = hours > 0 ? "\(hours)h \(minutes)m until full" : "\(minutes)m until full"
                            } else if capacity == 100 {
                                timeStr = "Fully charged"
                            } else {
                                timeStr = self.calculateFallbackTime(isPluggedIn: isPluggedIn)
                                if timeStr == "Calculating..." && !isChargingSys {
                                    timeStr = "Not charging"
                                }
                            }
                        } else {
                            if sysTimeToEmpty > 0 && sysTimeToEmpty < 10000 {
                                let hours = sysTimeToEmpty / 60
                                let minutes = sysTimeToEmpty % 60
                                timeStr = hours > 0 ? "\(hours)h \(minutes)m remaining" : "\(minutes)m remaining"
                            } else {
                                timeStr = self.calculateFallbackTime(isPluggedIn: isPluggedIn)
                            }
                        }
                        
                        var cycleCount = 0
                        var health = 100
                        var condition = "Normal"
                        
                        var powerDrawStr = "0.0 W"
                        if let battery = self.getBatteryDescriptionFast() {
                            cycleCount = battery["CycleCount"] as? Int ?? 0
                            if let cond = battery["BatteryHealth"] as? String {
                                condition = cond
                            }
                            let nominal = (battery["BatteryData"] as? [String: Any])?["NominalChargeCapacity"] as? Double ?? 0
                            let design = (battery["BatteryData"] as? [String: Any])?["DesignCapacity"] as? Double ?? 0
                            if design > 0 {
                                health = Int((nominal / design) * 100)
                            }
                            
                            let voltage = battery["Voltage"] as? Double ?? (battery["AppleRawBatteryVoltage"] as? Double ?? 0.0)
                            var amperage = 0.0
                            if let ampNumber = battery["Amperage"] as? NSNumber {
                                amperage = Double(Int64(bitPattern: ampNumber.uint64Value))
                            }
                            if amperage == 0.0, let instAmpNumber = battery["InstantAmperage"] as? NSNumber {
                                amperage = Double(Int64(bitPattern: instAmpNumber.uint64Value))
                            }
                            
                            if voltage > 0 && amperage != 0 {
                                let watts = abs((voltage / 1000.0) * (amperage / 1000.0))
                                let prefix = isChargingSys ? "+" : "-"
                                powerDrawStr = String(format: "%@%.1f W", prefix, watts)
                            } else {
                                if let adapter = battery["AdapterDetails"] as? [String: Any], let adapterWatts = adapter["Watts"] as? NSNumber {
                                    powerDrawStr = "AC \(adapterWatts.intValue)W"
                                }
                            }
                        }
                        
                        DispatchQueue.main.async {
                            manager.updateBatteryState(percentage: capacity, pluggedIn: isPluggedIn, timeRemaining: timeStr, cycleCount: cycleCount, healthPercentage: health, condition: condition, powerDraw: powerDrawStr)
                        }
                    }
                    
                    lastChargingState["InternalBattery"] = isPluggedIn
                    lastCapacity["InternalBattery"] = capacity
                } else {
                    if !initial {
                        let prevPluggedIn = lastChargingState[name] ?? isPluggedIn
                        let prevCapacity = lastCapacity[name] ?? capacity
                        
                        if prevPluggedIn != isPluggedIn {
                            DispatchQueue.main.async {
                                manager.triggerAccessoryBatteryIndicator(deviceName: name, percentage: capacity, isPluggedIn: isPluggedIn, isWarning: false)
                            }
                        } else if capacity != prevCapacity {
                            if capacity == 100 && prevCapacity < 100 {
                                DispatchQueue.main.async {
                                    manager.triggerAccessoryBatteryIndicator(deviceName: name, percentage: capacity, isPluggedIn: isPluggedIn, isWarning: false)
                                }
                            } else if capacity <= 20 && prevCapacity > 20 {
                                DispatchQueue.main.async {
                                    manager.triggerAccessoryBatteryIndicator(deviceName: name, percentage: capacity, isPluggedIn: isPluggedIn, isWarning: true)
                                }
                            } else if capacity <= 10 && prevCapacity > 10 {
                                DispatchQueue.main.async {
                                    manager.triggerAccessoryBatteryIndicator(deviceName: name, percentage: capacity, isPluggedIn: isPluggedIn, isWarning: true)
                                }
                            }
                        }
                    }
                    
                    // Zawsze aktualizuj stan w MediaKeyManager dla Ustawień
                    DispatchQueue.main.async {
                        manager.updateAccessoryState(deviceName: name, percentage: capacity, isPluggedIn: isPluggedIn)
                    }
                    
                    lastChargingState[name] = isPluggedIn
                    lastCapacity[name] = capacity
                }
            }
        }
    }
    
    private func getBatteryDescription() -> [String: Any]? {
        let task = Process()
        task.launchPath = "/usr/sbin/ioreg"
        task.arguments = ["-rn", "AppleSmartBattery", "-a"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [[String: Any]] else { return nil }
        return plist.first
    }
    
    private func calculateFallbackTime(isPluggedIn: Bool) -> String {
        guard let battery = self.getBatteryDescriptionFast() else { return "Calculating..." }
        let amperageRaw = (battery["BatteryData"] as? [String: Any])?["Amperage"] as? Double ?? battery["Amperage"] as? Double ?? 0
        
        if self.smoothedAmperage != nil {
            self.smoothedAmperage = (self.smoothedAmperage! * 0.8) + (amperageRaw * 0.2)
        } else {
            self.smoothedAmperage = amperageRaw
        }
        
        let amperage = self.smoothedAmperage ?? amperageRaw
        
        let currentCapacity = (battery["BatteryData"] as? [String: Any])?["RemainingCapacity"] as? Double ?? battery["CurrentCapacity"] as? Double ?? 0
        let maxCapacity = (battery["BatteryData"] as? [String: Any])?["FullChargeCapacity"] as? Double ?? battery["MaxCapacity"] as? Double ?? 0
        
        if amperage == 0 || maxCapacity == 0 {
            return "Calculating..."
        }
        
        if isPluggedIn {
            let capacityNeeded = maxCapacity - currentCapacity
            let hoursLeft = capacityNeeded / abs(amperage)
            let totalMinutes = Int(hoursLeft * 60)
            
            if totalMinutes <= 0 || totalMinutes > 10000 { return "Calculating..." }
            
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            let timeString = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
            return "\(timeString) until full"
            
        } else {
            let capacityAvailable = currentCapacity
            let hoursLeft = capacityAvailable / abs(amperage)
            let totalMinutes = Int(hoursLeft * 60)
            if totalMinutes <= 0 || totalMinutes > 10000 { return "Calculating..." }
            
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            let timeString = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
            return "\(timeString) remaining"
        }
    }
    
    deinit {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source.takeUnretainedValue(), .defaultMode)
        }
    }
}
