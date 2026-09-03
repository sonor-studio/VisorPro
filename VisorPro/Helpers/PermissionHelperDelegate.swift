import CoreLocation

class PermissionHelperDelegate: NSObject, CLLocationManagerDelegate {
    static let shared = PermissionHelperDelegate()
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        // Forces the manager to update its internal state
    }
}
