import SwiftUI
import AppKit
import IOBluetooth

extension MediaKeyManager {
    func triggerPeripheralIndicator(id: String? = nil, deviceName: String, type: String, typeIcon: String, isConnected: Bool, details: [String: String]? = nil) {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !self.enablePeripheral { return }
            
            let notifId = id ?? deviceName
            // Fix for USB bus resets: delay disconnects by 3s. If reconnect happens within 3s, ignore both.
            let debounceKey = "peripheral_debounce_\(notifId)"
            if !isConnected {
                self.notificationTimers[debounceKey]?.invalidate()
                self.notificationTimers[debounceKey] = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                    self?.notificationTimers.removeValue(forKey: debounceKey)
                    self?.showPeripheralOverlay(id: notifId, deviceName: deviceName, type: type, typeIcon: typeIcon, isConnected: false, details: details)
                }
            } else {
                if let timer = self.notificationTimers[debounceKey] {
                    let wasValid = timer.isValid
                    timer.invalidate()
                    self.notificationTimers.removeValue(forKey: debounceKey)
                    
                    if wasValid {
                        // It reconnected before the 1s timer fired. This was a bus reset. Ignore it to prevent spam.
                        return
                    }
                }
                self.showPeripheralOverlay(id: notifId, deviceName: deviceName, type: type, typeIcon: typeIcon, isConnected: true, details: details)
            }
        }
    }

    func fetchBluetoothDetails() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.btPoller?.forcePoll()
        }
    }

    func triggerBluetoothIndicator(deviceName: String, deviceAddress: String, isConnected: Bool) {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }

        if !enableBluetooth { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if !self.bluetoothHistory.contains(deviceName) {
                self.bluetoothHistory.append(deviceName)
            }
        }
        
        if isConnected && !notifyOnBluetoothConnect { return }
        if !isConnected && !notifyOnBluetoothDisconnect { return }
        if bluetoothBlocklist.contains(deviceName) { return }
        
        let now = Date()
        let eventKey = "\(deviceAddress)_\(isConnected ? "connect" : "disconnect")"
        if let lastTime = lastBluetoothEventTimeByDevice[eventKey], now.timeIntervalSince(lastTime) < 2.0 {
            return
        }
        lastBluetoothEventTimeByDevice[eventKey] = now
        
        let soundToPlay = isConnected ? soundOnBluetoothConnect : soundOnBluetoothDisconnect
        playNotificationSound(named: soundToPlay)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let pos = self.getOverlayPosition(for: "bluetoothOverlayPosition")
            self.dismissCollidingIndicators(newPosition: pos, source: "bluetooth")
            
            let newNotif = DeviceNotification(id: deviceAddress, deviceName: deviceName, type: "bluetooth", icon: "bluetooth", isConnected: isConnected, timestamp: Date())
            
            withAnimation(.easeInOut(duration: 0.15)) {
                if let idx = self.activeBluetoothNotifications.firstIndex(where: { $0.id == deviceAddress }) {
                    self.activeBluetoothNotifications[idx] = newNotif
                } else {
                    self.activeBluetoothNotifications.append(newNotif)
                    self.notifyOverlayStateChanged()
                }
                self.enforceNotificationLimit()
            }
            
            let timerKey = "bluetooth_\(deviceAddress)"
            self.notificationTimers[timerKey]?.invalidate(); self.overlayTriggerTimes[timerKey] = Date()
            self.notificationTimers[timerKey] = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    self?.activeBluetoothNotifications.removeAll(where: { $0.id == deviceAddress })
                }
            }
        }
    }
}
