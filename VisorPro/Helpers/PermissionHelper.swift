import CoreLocation
import AppKit
import CoreBluetooth

struct PermissionHelper {
    static let sharedLocationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = PermissionHelperDelegate.shared
        return manager
    }()
    
    static func hasLocationPermission() -> Bool {
        let status = sharedLocationManager.authorizationStatus
        return status != .denied && status != .restricted
    }
    
    static func isLocationNotDetermined() -> Bool {
        return sharedLocationManager.authorizationStatus == .notDetermined
    }
    
    static func checkBluetoothPermission() -> Bool {
        if #available(macOS 11.0, *) {
            let status = CBManager.authorization
            return status != .denied && status != .restricted
        }
        return true
    }
    
    static func openPrivacySettings(for type: String) {
        var urlString = "x-apple.systempreferences:com.apple.preference.security"
        switch type {
        case "Location":
            urlString += "?Privacy_LocationServices"
        case "Bluetooth":
            urlString += "?Privacy_Bluetooth"
        case "AppleEvents":
            urlString += "?Privacy_Automation"
        case "Microphone":
            urlString += "?Privacy_Microphone"
        default:
            break
        }
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
