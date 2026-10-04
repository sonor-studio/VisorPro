import CoreLocation

class PermissionHelperDelegate: NSObject, CLLocationManagerDelegate {
    static let shared = PermissionHelperDelegate()
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        NotificationCenter.default.post(name: Notification.Name("LocationAuthorizationChanged"), object: status)
        
        // Auto-enable Wi-Fi module when user grants location permission from the system dialog
        DispatchQueue.main.async {
            let mgr = MediaKeyManager.shared
            if status == .authorizedAlways || status == .authorized {
                if !mgr.enableWiFi {
                    mgr.enableWiFi = true
                }
            } else if status == .denied || status == .restricted {
                if mgr.enableWiFi {
                    mgr.enableWiFi = false
                }
            }
        }
    }
}
