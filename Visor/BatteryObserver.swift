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
                                manager.lastAction = isPluggedIn ? "Podłączono zasilanie ⚡️" : "Odłączono zasilanie 🔋"
                            }
                        }
                        
                        if let lastCap = lastCapacity["InternalBattery"], lastCap != capacity {
                            if let target = Int(manager.targetBatteryPercentage) {
                                if capacity == target {
                                    DispatchQueue.main.async {
                                        manager.lastAction = "Bateria osiągnęła \(target)%!"
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
                                timeStr = hours > 0 ? "\(hours)h \(minutes)m do pełnego" : "\(minutes)m do pełnego"
                            } else if capacity == 100 {
                                timeStr = "W pełni naładowana"
                            } else {
                                timeStr = self.calculateFallbackTime(isPluggedIn: isPluggedIn)
                                if timeStr == "Obliczanie..." && !isChargingSys {
                                    timeStr = "Nie ładuje"
                                }
                            }
                        } else {
                            if sysTimeToEmpty > 0 && sysTimeToEmpty < 10000 {
                                let hours = sysTimeToEmpty / 60
                                let minutes = sysTimeToEmpty % 60
                                timeStr = hours > 0 ? "\(hours)h \(minutes)m pozostało" : "\(minutes)m pozostało"
                            } else {
                                timeStr = self.calculateFallbackTime(isPluggedIn: isPluggedIn)
                            }
                        }
                        
                        var cycleCount = 0
                        var health = 100
                        var condition = "Normal"
                        
                        if let battery = self.getBatteryDescription() {
                            cycleCount = battery["CycleCount"] as? Int ?? 0
                            if let cond = battery["BatteryHealth"] as? String {
                                condition = cond
                            }
                            let nominal = (battery["BatteryData"] as? [String: Any])?["NominalChargeCapacity"] as? Double ?? 0
                            let design = (battery["BatteryData"] as? [String: Any])?["DesignCapacity"] as? Double ?? 0
                            if design > 0 {
                                health = Int((nominal / design) * 100)
                            }
                        }
                        
                        DispatchQueue.main.async {
                            manager.updateBatteryState(percentage: capacity, pluggedIn: isPluggedIn, timeRemaining: timeStr, cycleCount: cycleCount, healthPercentage: health, condition: condition)
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
        guard let battery = self.getBatteryDescription() else { return "Obliczanie..." }
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
            return "Obliczanie..."
        }
        
        if isPluggedIn {
            let capacityNeeded = maxCapacity - currentCapacity
            let hoursLeft = capacityNeeded / abs(amperage)
            let totalMinutes = Int(hoursLeft * 60)
            
            if totalMinutes <= 0 || totalMinutes > 10000 { return "Obliczanie..." }
            
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            let timeString = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
            return "\(timeString) do pełnego"
            
        } else {
            let capacityAvailable = currentCapacity
            let hoursLeft = capacityAvailable / abs(amperage)
            let totalMinutes = Int(hoursLeft * 60)
            
            if totalMinutes <= 0 || totalMinutes > 10000 { return "Obliczanie..." }
            
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            let timeString = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
            return "\(timeString) pozostało"
        }
    }
    
    deinit {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source.takeUnretainedValue(), .defaultMode)
        }
    }
}
