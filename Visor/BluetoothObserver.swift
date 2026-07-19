import Foundation
import IOBluetooth

class BluetoothObserver: NSObject {
    private weak var manager: MediaKeyManager?
    private var connectNotification: IOBluetoothUserNotification?
    
    init(manager: MediaKeyManager) {
        self.manager = manager
        super.init()
        startObserving()
    }
    
    func startObserving() {
        connectNotification = IOBluetoothDevice.register(forConnectNotifications: self,
                                                         selector: #selector(deviceDidConnect(_:fromDevice:)))
    }
    
    @objc func deviceDidConnect(_ notification: IOBluetoothUserNotification, fromDevice device: IOBluetoothDevice) {
        let name = device.name ?? "Nieznane urządzenie"
        DispatchQueue.main.async {
            if self.manager?.useSystemOSD == false {
                self.manager?.lastAction = "Podłączono Bluetooth: \(name)"
            }
        }
        
        device.register(forDisconnectNotification: self,
                        selector: #selector(deviceDidDisconnect(_:fromDevice:)))
    }
    
    @objc func deviceDidDisconnect(_ notification: IOBluetoothUserNotification, fromDevice device: IOBluetoothDevice) {
        let name = device.name ?? "Nieznane urządzenie"
        DispatchQueue.main.async {
            if self.manager?.useSystemOSD == false {
                self.manager?.lastAction = "Odłączono Bluetooth: \(name)"
            }
        }
    }
}
