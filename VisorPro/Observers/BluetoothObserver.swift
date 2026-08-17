import Foundation
import IOBluetooth

class BluetoothObserver: NSObject {
    private weak var manager: MediaKeyManager?
    private var connectNotification: IOBluetoothUserNotification?
    private var isInitialLoad: Bool = true
    private var lastConnectedDeviceNames: [String: Date] = [:]
    
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
    
    @objc func deviceDidConnect(_ notification: IOBluetoothUserNotification, fromDevice device: IOBluetoothDevice) {
        if isInitialLoad { return }
        if !shouldShowNotification(for: device) { return }
        guard let rawName = device.name else { return } // Ignoruj urządzenia bez nazwy
        
        let name = rawName.replacingOccurrences(of: "’", with: "'")
        
        if let lastTime = lastConnectedDeviceNames[name], Date().timeIntervalSince(lastTime) < 5.0 {
            return
        }
        lastConnectedDeviceNames[name] = Date()
        let macAddress = device.addressString.replacingOccurrences(of: "-", with: ":").uppercased()
        DispatchQueue.main.async {
            if self.manager?.useSystemOSD == false {
                self.manager?.triggerBluetoothIndicator(deviceName: name, deviceAddress: macAddress, isConnected: true)
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
        
        let name = rawName.replacingOccurrences(of: "’", with: "'")
        let macAddress = device.addressString.replacingOccurrences(of: "-", with: ":").uppercased()
        DispatchQueue.main.async {
            if self.manager?.useSystemOSD == false {
                self.manager?.triggerBluetoothIndicator(deviceName: name, deviceAddress: macAddress, isConnected: false)
                self.manager?.lastAction = "Bluetooth Disconnected: \(name)"
            }
        }
    }
}
