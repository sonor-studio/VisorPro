import Foundation
import IOBluetooth

class BluetoothObserver: NSObject {
    private weak var manager: MediaKeyManager?
    private var connectNotification: IOBluetoothUserNotification?
    private var isInitialLoad: Bool = true
    
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
        // Pokazuj powiadomienia TYLKO dla sprzętu audio (słuchawki, AirPods) 
        // i peryferiów (myszki, klawiatury, pady)
        return majorClass == kBluetoothDeviceClassMajorAudio || 
               majorClass == kBluetoothDeviceClassMajorPeripheral
    }
    
    @objc func deviceDidConnect(_ notification: IOBluetoothUserNotification, fromDevice device: IOBluetoothDevice) {
        if isInitialLoad { return }
        if !shouldShowNotification(for: device) {
            return
        }
        
        let name = device.nameOrAddress ?? "Unknown Device"
        DispatchQueue.main.async {
            if self.manager?.useSystemOSD == false {
                self.manager?.triggerBluetoothIndicator(deviceName: name, isConnected: true)
                self.manager?.lastAction = "Bluetooth Connected: \(name)"
            }
        }
        
        device.register(forDisconnectNotification: self,
                        selector: #selector(deviceDidDisconnect(_:fromDevice:)))
    }
    
    @objc func deviceDidDisconnect(_ notification: IOBluetoothUserNotification, fromDevice device: IOBluetoothDevice) {
        if isInitialLoad { return }
        if !shouldShowNotification(for: device) {
            return
        }
        
        let name = device.nameOrAddress ?? "Unknown Device"
        DispatchQueue.main.async {
            if self.manager?.useSystemOSD == false {
                self.manager?.triggerBluetoothIndicator(deviceName: name, isConnected: false)
                self.manager?.lastAction = "Bluetooth Disconnected: \(name)"
            }
        }
    }
}
