import Foundation
import IOKit.ps

class BatteryObserver {
    private weak var manager: MediaKeyManager?
    private var runLoopSource: Unmanaged<CFRunLoopSource>?
    
    private var lastChargingState: Bool?
    private var lastCapacity: Int?
    
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
                let state = description[kIOPSPowerSourceStateKey] as? String ?? ""
                let isPluggedIn = (state == kIOPSACPowerValue)
                let capacity = description[kIOPSCurrentCapacityKey] as? Int ?? -1
                
                if !initial && !manager.useSystemOSD {
                    // Powiadomienie o podłączeniu kabla
                    if let lastState = lastChargingState, lastState != isPluggedIn {
                        DispatchQueue.main.async {
                            manager.lastAction = isPluggedIn ? "Podłączono zasilanie ⚡️" : "Odłączono zasilanie 🔋"
                        }
                    }
                    
                    // Powiadomienie o osiągnięciu konkretnego procentu
                    if let lastCap = lastCapacity, lastCap != capacity {
                        if let target = Int(manager.targetBatteryPercentage) {
                            if capacity == target {
                                DispatchQueue.main.async {
                                    manager.lastAction = "Bateria osiągnęła \(target)%!"
                                }
                            }
                        }
                    }
                }
                
                // Zawsze aktualizuj poziom baterii i stan zasilania
                DispatchQueue.main.async {
                    manager.updateBatteryState(percentage: capacity, pluggedIn: isPluggedIn)
                }
                
                lastChargingState = isPluggedIn
                lastCapacity = capacity
                break
            }
        }
    }
    
    deinit {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source.takeUnretainedValue(), .defaultMode)
        }
    }
}
