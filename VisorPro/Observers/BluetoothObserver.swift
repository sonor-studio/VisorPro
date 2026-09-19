import Foundation
import IOBluetooth

class BluetoothObserver: NSObject {
    private weak var manager: MediaKeyManager?
    private var connectNotification: IOBluetoothUserNotification?
    private var isInitialLoad: Bool = true
    private var lastConnectedDeviceNames: [String: Date] = [:]
    private var macToDeviceName: [String: String] = [:]
    private var currentlyConnectedMACs: Set<String> = []
    
    init(manager: MediaKeyManager) {
        self.manager = manager
        super.init()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isInitialLoad = false
        }
        
        startObserving()
    }
    
    func startObserving() {
        if let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] {
            for device in paired {
                if device.isConnected() {
                    let mac = device.addressString.replacingOccurrences(of: "-", with: ":").uppercased()
                    currentlyConnectedMACs.insert(mac)
                }
            }
        }
        
        connectNotification = IOBluetoothDevice.register(forConnectNotifications: self,
                                                         selector: #selector(deviceDidConnect(_:fromDevice:)))
    }
    
    private func shouldShowNotification(for device: IOBluetoothDevice) -> Bool {
        let majorClass = device.deviceClassMajor
        // 0 = Miscellaneous (often iPhones/Apple Watches), 1 = Computer, 2 = Phone, 3 = LAN/Network Access Point
        if majorClass == 0 || majorClass == 1 || majorClass == 2 || majorClass == 3 {
            return false
        }
        return true
    }
    
    private func findAccessoryBaseName(name: String, macAddress: String) -> String? {
        let history = self.manager?.accessoryBatteryHistory ?? []
        let systemName = self.manager?.bluetoothDetails[macAddress]?["SystemName"] ?? name
        
        let cleanSystemName = systemName.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression).lowercased()
        let cleanName = name.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression).lowercased()
        
        let entry = history.first { entry in
            let cleanEntryBase = entry
                .replacingOccurrences(of: " (Left)", with: "")
                .replacingOccurrences(of: " (Right)", with: "")
                .replacingOccurrences(of: " (Case)", with: "")
                .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
                .lowercased()
            return cleanEntryBase == cleanName || cleanEntryBase.contains(cleanName) || cleanName.contains(cleanEntryBase) ||
                   cleanEntryBase == cleanSystemName || cleanEntryBase.contains(cleanSystemName) || cleanSystemName.contains(cleanEntryBase)
        }
        
        if let entry = entry {
            return entry
                .replacingOccurrences(of: " (Left)", with: "")
                .replacingOccurrences(of: " (Right)", with: "")
                .replacingOccurrences(of: " (Case)", with: "")
        }
        
        let lower = name.lowercased()
        if lower.contains("mouse") || lower.contains("mysz") || lower.contains("keyboard") || lower.contains("klawiatura") || lower.contains("trackpad") {
            return name
        }
        
        return nil
    }

    @objc func deviceDidConnect(_ notification: IOBluetoothUserNotification, fromDevice device: IOBluetoothDevice) {
        if isInitialLoad { return }
        if !shouldShowNotification(for: device) { return }
        guard let rawName = device.name else { return }
        
        let name = rawName.replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: " (Left)", with: "")
            .replacingOccurrences(of: " (Right)", with: "")
            .replacingOccurrences(of: " (Lewa)", with: "")
            .replacingOccurrences(of: " (Prawa)", with: "")
            .replacingOccurrences(of: " (Case)", with: "")
            .replacingOccurrences(of: " (Etui)", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        if let lastTime = lastConnectedDeviceNames[name], Date().timeIntervalSince(lastTime) < 5.0 {
            return
        }
        lastConnectedDeviceNames[name] = Date()
        let macAddress = device.addressString.replacingOccurrences(of: "-", with: ":").uppercased()
        
        // If it was ALREADY in the set of connected MACs, this is a phantom event (like switching Listening Modes)
        if currentlyConnectedMACs.contains(macAddress) {
            return
        }
        currentlyConnectedMACs.insert(macAddress)
        
        macToDeviceName[macAddress] = name
        
        DispatchQueue.main.async {
            if self.manager?.useSystemOSD == false {
                if name.lowercased().contains("airpods") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        let timeSinceLidOpen = Date().timeIntervalSince(AirPodsBatteryManager.shared.lastLidOpenTime)
                        if timeSinceLidOpen > 15.0 {
                            self.manager?.triggerBluetoothIndicator(deviceName: name, deviceAddress: "AIRPODS_CONNECTION", isConnected: true)
                            self.manager?.lastAction = "Bluetooth Connected (AirPods): \(name)"
                        }
                    }
                } else if let baseName = self.findAccessoryBaseName(name: name, macAddress: macAddress) {
                    self.manager?.triggerAccessoryConnection(deviceName: baseName, deviceAddress: macAddress, isConnected: true)
                    self.manager?.lastAction = "Bluetooth Connected: \(name)"
                } else {
                    self.manager?.triggerBluetoothIndicator(deviceName: name, deviceAddress: macAddress, isConnected: true)
                    self.manager?.lastAction = "Bluetooth Connected: \(name)"
                }
                self.manager?.fetchBluetoothDetails()
            }
        }
        
        device.register(forDisconnectNotification: self,
                        selector: #selector(deviceDidDisconnect(_:fromDevice:)))
    }
    
    @objc func deviceDidDisconnect(_ notification: IOBluetoothUserNotification, fromDevice device: IOBluetoothDevice) {
        if isInitialLoad { return }
        if !shouldShowNotification(for: device) { return }
        guard let rawName = device.name else { return }
        
        let macAddress = device.addressString.replacingOccurrences(of: "-", with: ":").uppercased()
        currentlyConnectedMACs.remove(macAddress)
        
        let name = (macToDeviceName[macAddress] ?? rawName.replacingOccurrences(of: "’", with: "'"))
            .replacingOccurrences(of: " (Left)", with: "")
            .replacingOccurrences(of: " (Right)", with: "")
            .replacingOccurrences(of: " (Lewa)", with: "")
            .replacingOccurrences(of: " (Prawa)", with: "")
            .replacingOccurrences(of: " (Case)", with: "")
            .replacingOccurrences(of: " (Etui)", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        DispatchQueue.main.async {
            if self.manager?.useSystemOSD == false {
                if name.lowercased().contains("airpods") {
                    let timeSinceLidClose = Date().timeIntervalSince(AirPodsBatteryManager.shared.lastLidCloseTime)
                    if timeSinceLidClose > 15.0 {
                        self.manager?.triggerBluetoothIndicator(deviceName: name, deviceAddress: "AIRPODS_CONNECTION", isConnected: false)
                        self.manager?.lastAction = "Bluetooth Disconnected (AirPods): \(name)"
                    }
                } else if let baseName = self.findAccessoryBaseName(name: name, macAddress: macAddress) {
                    self.manager?.triggerAccessoryConnection(deviceName: baseName, deviceAddress: macAddress, isConnected: false)
                    self.manager?.lastAction = "Bluetooth Disconnected: \(name)"
                } else {
                    self.manager?.triggerBluetoothIndicator(deviceName: name, deviceAddress: macAddress, isConnected: false)
                    self.manager?.lastAction = "Bluetooth Disconnected: \(name)"
                }
            }
        }
    }
}
