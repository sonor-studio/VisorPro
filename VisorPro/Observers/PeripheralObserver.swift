import SwiftUI

class PeripheralObserver {
    private weak var manager: MediaKeyManager?
    private var notifyPort: IONotificationPortRef?
    private var runLoopSource: CFRunLoopSource?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    
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
        while case let device = IOIteratorNext(iterator), device != 0 {
            if !initial {
                handleDevice(device: device, isConnected: true)
            }
            IOObjectRelease(device)
        }
    }
    
    private func deviceRemoved(iterator: io_iterator_t, initial: Bool = false) {
        while case let device = IOIteratorNext(iterator), device != 0 {
            if !initial {
                handleDevice(device: device, isConnected: false)
            }
            IOObjectRelease(device)
        }
    }
    
    private func handleDevice(device: io_object_t, isConnected: Bool) {
        var nameCString = [CChar](repeating: 0, count: 256)
        let result = IORegistryEntryGetName(device, &nameCString)
        if result == KERN_SUCCESS {
            let name = String(cString: nameCString)
            
            // Ignore generic host controllers or roots
            if name.lowercased().contains("root hub") { return }
            
            var type = "USB Device"
            var typeIcon = "cable.connector"
            
            if let cfClass = IORegistryEntryCreateCFProperty(device, "bDeviceClass" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber {
                let devClass = cfClass.intValue
                if devClass == 9 {
                    type = "USB Hub"
                    typeIcon = "point.3.connected.trianglepath.dotted"
                } else if devClass == 8 {
                    type = "USB Drive"
                    typeIcon = "externaldrive"
                } else if devClass == 3 {
                    type = "HID Device"
                    typeIcon = "keyboard"
                }
            }
            
            let lowerName = name.lowercased()
            if lowerName.contains("keyboard") || lowerName.contains("keychron") {
                type = "Keyboard"
                typeIcon = "keyboard"
            } else if lowerName.contains("mouse") || lowerName.contains("receiver") || lowerName.contains("logi") {
                type = "Mouse"
                typeIcon = "magicmouse"
            } else if lowerName.contains("hub") {
                type = "USB Hub"
                typeIcon = "point.3.connected.trianglepath.dotted"
            } else if lowerName.contains("drive") || lowerName.contains("sandisk") || lowerName.contains("ssd") || lowerName.contains("mass storage") || lowerName.contains("memory") || lowerName.contains("disk") || lowerName.contains("storage") || lowerName.contains("flash") || lowerName.contains("stick") {
                type = "USB Drive"
                typeIcon = "externaldrive"
            } else if lowerName.contains("audio") || lowerName.contains("mic") {
                type = "Audio Device"
                typeIcon = "headphones"
            }
            
            // Check if we should suppress due to a recent display connection
            if let lastDisplayTime = manager?.lastDisplayConnectionTime, Date().timeIntervalSince(lastDisplayTime) < 3.0 {
                // If it's a generic hub or audio device connecting precisely when a display connects, ignore it to prevent overlay clutter.
                if isConnected && (type == "USB Hub" || type == "Audio Device" || type == "USB Device") {
                    return
                }
            }
            
            // If the name is something generic like "USB2.0 Hub", we rely on the type.
            let displayName = name.count > 0 ? name : type
            
            var details: [String: String] = [:]
            
            var propsUnmanaged: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(device, &propsUnmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let props = propsUnmanaged?.takeRetainedValue() as? [String: Any] {
                
                if let vendor = props["USB Vendor Name"] as? String {
                    details["Vendor"] = vendor.trimmingCharacters(in: .whitespacesAndNewlines)
                } else if let vendor = props["kUSBVendorString"] as? String {
                    details["Vendor"] = vendor.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                if let product = props["USB Product Name"] as? String {
                    details["Product"] = product.trimmingCharacters(in: .whitespacesAndNewlines)
                } else if let product = props["kUSBProductString"] as? String {
                    details["Product"] = product.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                if let serial = props["USB Serial Number"] as? String, !serial.isEmpty {
                    details["Serial"] = serial.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                if let vid = props["idVendor"] as? Int, let pid = props["idProduct"] as? Int {
                    details["Device ID"] = String(format: "0x%04X:0x%04X", vid, pid)
                }
                
                if let speed = props["Device Speed"] as? Int {
                    let speedStr: String
                    switch speed {
                        case 0: speedStr = "Low (1.5 Mbps)"
                        case 1: speedStr = "Full (12 Mbps)"
                        case 2: speedStr = "High (480 Mbps)"
                        case 3: speedStr = "Super (5 Gbps)"
                        case 4: speedStr = "Super+ (10+ Gbps)"
                        default: speedStr = "Unknown"
                    }
                    details["Speed"] = speedStr
                }
                
                if let busPower = props["Bus Power Used"] as? Int {
                    if busPower > 0 {
                        details["Power Used"] = "\(busPower * 2) mA"
                    }
                }
            }
            
            // Extract BSD Name to reliably link the USB device to a volume
            if let bsdName = findDiskBSDName(for: device) {
                details["BSD Name"] = bsdName
            }
            
            manager?.triggerPeripheralIndicator(deviceName: displayName, type: type, typeIcon: typeIcon, isConnected: isConnected, details: details.isEmpty ? nil : details)
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
