import Foundation
import IOBluetooth

class BluetoothObserver: NSObject {
    private weak var manager: MediaKeyManager?
    private var connectNotification: IOBluetoothUserNotification?
    private var isInitialLoad: Bool = true
    private var lastConnectedDeviceNames: [String: Date] = [:]
    private var macToDeviceName: [String: String] = [:]
    
    init(manager: MediaKeyManager) {
        self.manager = manager
        super.init()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isInitialLoad = false
        }
        
        startObserving()
    }
    
    func startObserving() {
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
        return nil
    }

    @objc func deviceDidConnect(_ notification: IOBluetoothUserNotification, fromDevice device: IOBluetoothDevice) {
        if isInitialLoad { return }
        if !shouldShowNotification(for: device) { return }
        guard let rawName = device.name else { return }
        
        let name = rawName.replacingOccurrences(of: "’", with: "'")
        
        if let lastTime = lastConnectedDeviceNames[name], Date().timeIntervalSince(lastTime) < 5.0 {
            return
        }
        lastConnectedDeviceNames[name] = Date()
        let macAddress = device.addressString.replacingOccurrences(of: "-", with: ":").uppercased()
        macToDeviceName[macAddress] = name
        
        DispatchQueue.main.async {
            if self.manager?.useSystemOSD == false {
                if let baseName = self.findAccessoryBaseName(name: name, macAddress: macAddress) {
                    self.manager?.triggerAccessoryConnection(deviceName: baseName, deviceAddress: macAddress, isConnected: true)
                } else {
                    self.manager?.triggerBluetoothIndicator(deviceName: name, deviceAddress: macAddress, isConnected: true)
                }
                self.manager?.lastAction = "Bluetooth Connected: \(name)"
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
        let name = macToDeviceName[macAddress] ?? rawName.replacingOccurrences(of: "’", with: "'")
        DispatchQueue.main.async {
            if self.manager?.useSystemOSD == false {
                if let baseName = self.findAccessoryBaseName(name: name, macAddress: macAddress) {
                    self.manager?.triggerAccessoryConnection(deviceName: baseName, deviceAddress: macAddress, isConnected: false)
                } else {
                    self.manager?.triggerBluetoothIndicator(deviceName: name, deviceAddress: macAddress, isConnected: false)
                }
                self.manager?.lastAction = "Bluetooth Disconnected: \(name)"
            }
        }
    }
}
