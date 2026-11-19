import CoreLocation

class PermissionHelperDelegate: NSObject, CLLocationManagerDelegate {
    static let shared = PermissionHelperDelegate()
    
    // Modern macOS 11+ delegate method
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        NotificationCenter.default.post(name: Notification.Name("LocationAuthorizationChanged"), object: status)
        
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
    
    // Legacy fallback for older macOS
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        locationManagerDidChangeAuthorization(manager)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        manager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        manager.stopUpdatingLocation()
    }
}
