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
            } else if lowerName.contains("drive") || lowerName.contains("sandisk") || lowerName.contains("ssd") {
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
                }
                if let product = props["USB Product Name"] as? String {
                    details["Product"] = product.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            manager?.triggerPeripheralIndicator(deviceName: displayName, type: type, typeIcon: typeIcon, isConnected: isConnected, details: details.isEmpty ? nil : details)
        }
    }
    
    deinit {
        if let notifyPort = notifyPort {
            IONotificationPortDestroy(notifyPort)
        }
        if addedIterator != 0 { IOObjectRelease(addedIterator) }
        if removedIterator != 0 { IOObjectRelease(removedIterator) }
    }
}
