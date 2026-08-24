import SwiftUI

class PeripheralObserver {
    private weak var manager: MediaKeyManager?
    private var notifyPort: IONotificationPortRef?
    private var runLoopSource: CFRunLoopSource?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    
    private var processedRegistryIDs: Set<UInt64> = []
    
    init(manager: MediaKeyManager) {
        self.manager = manager
        startObserving()
    }
    
    private func startObserving() {
        notifyPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let notifyPort = notifyPort else { return }
        runLoopSource = IONotificationPortGetRunLoopSource(notifyPort).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
        
        let matchDict = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
        let matchDictRemove = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        // Match Add
        IOServiceAddMatchingNotification(
            notifyPort,
            kIOFirstMatchNotification,
            matchDict,
            { context, iterator in
                let mySelf = Unmanaged<PeripheralObserver>.fromOpaque(context!).takeUnretainedValue()
                mySelf.deviceAdded(iterator: iterator)
            },
            selfPtr,
            &addedIterator
        )
        deviceAdded(iterator: addedIterator, initial: true)
        
        // Match Remove
        IOServiceAddMatchingNotification(
            notifyPort,
            kIOTerminatedNotification,
            matchDictRemove,
            { context, iterator in
                let mySelf = Unmanaged<PeripheralObserver>.fromOpaque(context!).takeUnretainedValue()
                mySelf.deviceRemoved(iterator: iterator)
            },
            selfPtr,
            &removedIterator
        )
        deviceRemoved(iterator: removedIterator, initial: true)
    }
    
    private func deviceAdded(iterator: io_iterator_t, initial: Bool = false) {
        processIterator(iterator, isConnected: true, initial: initial)
    }
    
    private func deviceRemoved(iterator: io_iterator_t, initial: Bool = false) {
        processIterator(iterator, isConnected: false, initial: initial)
    }
    
    private func processIterator(_ iterator: io_iterator_t, isConnected: Bool, initial: Bool) {
        var device: io_object_t = 0
        repeat {
            device = IOIteratorNext(iterator)
            
            if device == 0 && IOIteratorIsValid(iterator) == 0 {
                IOIteratorReset(iterator)
                device = IOIteratorNext(iterator)
            }
            
            if device != 0 {
                var entryID: UInt64 = 0
                let kr = IORegistryEntryGetRegistryEntryID(device, &entryID)
                let validID = (kr == KERN_SUCCESS && entryID != 0)
                
                let shouldProcess: Bool
                if validID {
                    if isConnected {
                        shouldProcess = !processedRegistryIDs.contains(entryID)
                        processedRegistryIDs.insert(entryID)
                    } else {
                        shouldProcess = processedRegistryIDs.contains(entryID)
                        processedRegistryIDs.remove(entryID)
                    }
                } else {
                    shouldProcess = true
                }
                
                if !initial && shouldProcess {
                    handleDevice(device: device, isConnected: isConnected)
                }
                IOObjectRelease(device)
            }
        } while device != 0 || IOIteratorIsValid(iterator) == 0
    }
    
    private func handleDevice(device: io_object_t, isConnected: Bool) {
        var nameCString = [CChar](repeating: 0, count: 256)
        let result = IORegistryEntryGetName(device, &nameCString)
        if result == KERN_SUCCESS {
            let name = String(cString: nameCString)
            
            var details: [String: String] = [:]
            var vendorName = ""
            var productName = ""
            var speedStr = "Unknown"
            
            var propsUnmanaged: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(device, &propsUnmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let props = propsUnmanaged?.takeRetainedValue() as? [String: Any] {
                
                if let vendor = props["USB Vendor Name"] as? String ?? props["kUSBVendorString"] as? String {
                    vendorName = vendor.trimmingCharacters(in: .whitespacesAndNewlines)
                    details["Vendor"] = vendorName
                }
                
                if let product = props["USB Product Name"] as? String ?? props["kUSBProductString"] as? String {
                    productName = product.trimmingCharacters(in: .whitespacesAndNewlines)
                    details["Product"] = productName
                }
                
                if let serial = props["USB Serial Number"] as? String, !serial.isEmpty {
                    details["Serial"] = serial.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                if let vid = props["idVendor"] as? Int, let pid = props["idProduct"] as? Int {
                    details["Device ID"] = String(format: "0x%04X:0x%04X", vid, pid)
                }
                
                if let speed = props["Device Speed"] as? Int {
                    switch speed {
                        case 0: speedStr = "Low (1.5 Mbps)"
                        case 1: speedStr = "Full (12 Mbps)"
                        case 2: speedStr = "High (480 Mbps)"
                        case 3: speedStr = "Super (5 Gbps)"
                        case 4: speedStr = "Super+ (10+ Gbps)"
                        default: break
                    }
                    details["Speed"] = speedStr
                }
                
                if let busPower = props["Bus Power Used"] as? Int, busPower > 0 {
                    details["Power Used"] = "\(busPower * 2) mA"
                }
            }
            
            let nameToCheck = (productName.isEmpty ? name : productName).lowercased()
            let lowerName = name.lowercased()
            
            let ignoreList = [
                "root hub", "iousbhostdevice", "io usb host device", "billboard"
            ]
            
            if ignoreList.contains(where: { nameToCheck.contains($0) || lowerName.contains($0) }) {
                return
            }
            
            var type = "USB Device"
            var typeIcon = "cable.connector"
            
            let isIPhone = nameToCheck.contains("iphone") || lowerName.contains("iphone")
            let isIPad = nameToCheck.contains("ipad") || lowerName.contains("ipad")
            let isIPod = nameToCheck.contains("ipod") || lowerName.contains("ipod")
            
            if let cfClass = IORegistryEntryCreateCFProperty(device, "bDeviceClass" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber {
                let devClass = cfClass.intValue
                if devClass == 9 {
                    return 
                } else if devClass == 8 {
                    type = "USB Drive"
                    typeIcon = "externaldrive"
                } else if devClass == 3 {
                    type = "HID Device"
                    typeIcon = "keyboard"
                }
            }
            
            if isIPhone {
                type = "iPhone"
                typeIcon = "iphone"
            } else if isIPad {
                type = "iPad"
                typeIcon = "ipad"
            } else if isIPod {
                type = "iPod"
                typeIcon = "ipod"
            } else if lowerName.contains("keyboard") || lowerName.contains("keychron") {
                type = "Keyboard"
                typeIcon = "keyboard"
            } else if lowerName.contains("mouse") || lowerName.contains("receiver") || lowerName.contains("logi") {
                type = "Mouse"
                typeIcon = "magicmouse"
            } else if lowerName.contains("cd-rom") || lowerName.contains("cd-rw") || lowerName.contains("dvd") || lowerName.contains("optical") || lowerName.contains("superdrive") || lowerName.contains("bluray") {
                type = "CD/DVD Drive"
                typeIcon = "opticaldisc"
            } else if lowerName.contains("drive") || lowerName.contains("sandisk") || lowerName.contains("ssd") || lowerName.contains("mass storage") || lowerName.contains("memory") || lowerName.contains("disk") || lowerName.contains("storage") || lowerName.contains("flash") || lowerName.contains("stick") {
                type = "USB Drive"
                typeIcon = "externaldrive"
            } else if lowerName.contains("audio") || lowerName.contains("mic") {
                type = "Audio Device"
                typeIcon = "headphones"
            }
            
            // Check for generic IOKit battery properties on the device
            if let batNum = IORegistryEntryCreateCFProperty(device, "BatteryPercent" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber {
                let bat = batNum.intValue
                details["Battery"] = "\(bat)%"
                details["BatteryLevel"] = "\(bat)"
            }
            
            // Check if we should suppress due to a recent display connection
            if let lastDisplayTime = manager?.lastDisplayConnectionTime, Date().timeIntervalSince(lastDisplayTime) < 3.0 {
                if isConnected && type == "Audio Device" {
                    return
                }
            }
            
            // If the name is something generic like "USB2.0 Hub", we rely on the type.
            let displayName = name.count > 0 ? name : type
            
            // Extract BSD Name to reliably link the USB device to a volume
            if let bsdName = findDiskBSDName(for: device) {
                details["BSD Name"] = bsdName
            }
            
            let finalType = type
            let finalIcon = typeIcon
            let deviceIdentifier = details["Serial"] ?? displayName
            
            if (isIPhone || isIPad || isIPod) && isConnected {
                fetchIOSDeviceInfo { [weak self] marketingName, battery, isCharging in
                    guard let self = self, let manager = self.manager else { return }
                    var updatedDetails = details
                    var updatedDisplayName = displayName
                    
                    if let model = marketingName, !model.isEmpty {
                        updatedDetails["Model"] = model
                        updatedDisplayName = model
                    }
                    
                    if let battery = battery {
                        updatedDetails["Battery"] = "\(battery)%" + (isCharging == true ? " (Charging)" : "")
                        updatedDetails["BatteryLevel"] = "\(battery)"
                        updatedDetails["Charging"] = (isCharging == true) ? "Yes" : "No"
                        
                        manager.updateAccessoryState(deviceName: updatedDisplayName, percentage: battery, isPluggedIn: isCharging ?? true)
                    }
                    
                    manager.triggerPeripheralIndicator(id: deviceIdentifier, deviceName: updatedDisplayName, type: finalType, typeIcon: finalIcon, isConnected: true, details: updatedDetails.isEmpty ? nil : updatedDetails)
                }
            } else {
                manager?.triggerPeripheralIndicator(id: deviceIdentifier, deviceName: displayName, type: finalType, typeIcon: finalIcon, isConnected: isConnected, details: details.isEmpty ? nil : details)
            }
        }
    }
    
    private func fetchIOSDeviceInfo(completion: @escaping (String?, Int?, Bool?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let candidates = [
                "/opt/homebrew/bin/ideviceinfo",
                "/usr/local/bin/ideviceinfo",
                "/usr/bin/ideviceinfo"
            ]
            guard let binary = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
                DispatchQueue.main.async { completion(nil, nil, nil) }
                return
            }
            
            // Retry up to 3 times with brief delays as usbmuxd establishes lockdown session
            for attempt in 0..<3 {
                if attempt > 0 {
                    Thread.sleep(forTimeInterval: 0.8)
                }
                
                let process = Process()
                process.executableURL = URL(fileURLWithPath: binary)
                process.arguments = ["-q", "com.apple.mobile.battery"]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    if process.terminationStatus == 0 {
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                            var battery: Int? = nil
                            var isCharging: Bool? = nil
                            
                            let lines = output.components(separatedBy: .newlines)
                            for line in lines {
                                let parts = line.components(separatedBy: ":")
                                guard parts.count == 2 else { continue }
                                let key = parts[0].trimmingCharacters(in: .whitespaces)
                                let val = parts[1].trimmingCharacters(in: .whitespaces)
                                if key == "BatteryCurrentCapacity", let intVal = Int(val) {
                                    battery = intVal
                                } else if key == "BatteryIsCharging" {
                                    isCharging = (val.lowercased() == "true")
                                }
                            }
                            
                            var devName: String? = nil
                            let nameProc = Process()
                            nameProc.executableURL = URL(fileURLWithPath: binary)
                            nameProc.arguments = ["-k", "MarketingName"]
                            let namePipe = Pipe()
                            nameProc.standardOutput = namePipe
                            nameProc.standardError = Pipe()
                            if let _ = try? nameProc.run() {
                                nameProc.waitUntilExit()
                                if nameProc.terminationStatus == 0 {
                                    let nData = namePipe.fileHandleForReading.readDataToEndOfFile()
                                    if let nStr = String(data: nData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !nStr.isEmpty {
                                        devName = nStr
                                    }
                                }
                            }
                            
                            DispatchQueue.main.async {
                                completion(devName, battery, isCharging)
                            }
                            return
                        }
                    }
                } catch {
                }
            }
            
            DispatchQueue.main.async {
                completion(nil, nil, nil)
            }
        }
    }
    
    private func findDiskBSDName(for device: io_registry_entry_t) -> String? {
        var iterator: io_iterator_t = 0
        guard IORegistryEntryCreateIterator(device, kIOServicePlane, IOOptionBits(kIORegistryIterateRecursively), &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var child = IOIteratorNext(iterator)
        while child != 0 {
            if let bsdRef = IORegistryEntryCreateCFProperty(child, "BSD Name" as CFString, kCFAllocatorDefault, 0),
               let bsdName = bsdRef as? String, bsdName.hasPrefix("disk") {
                IOObjectRelease(child)
                return bsdName
            }
            IOObjectRelease(child)
            child = IOIteratorNext(iterator)
        }
        return nil
    }
    
    deinit {
        if let notifyPort = notifyPort {
            IONotificationPortDestroy(notifyPort)
        }
        if addedIterator != 0 { IOObjectRelease(addedIterator) }
        if removedIterator != 0 { IOObjectRelease(removedIterator) }
    }
}
