import CoreLocation
import AppKit
import CoreBluetooth
import AVFoundation

final class BluetoothPermissionDelegate: NSObject, CBCentralManagerDelegate {
    static let shared = BluetoothPermissionDelegate()
    private var centralManager: CBCentralManager?
    
    func requestPermission() {
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: false])
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        NotificationCenter.default.post(name: Notification.Name("BluetoothAuthorizationChanged"), object: nil)
    }
}

struct PermissionHelper {
    static let sharedLocationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = PermissionHelperDelegate.shared
        return manager
    }()
    
    // MARK: - Location
    static func hasLocationPermission() -> Bool {
        guard CLLocationManager.locationServicesEnabled() else { return false }
        let status = sharedLocationManager.authorizationStatus
        return status == .authorizedAlways || status == .authorized
    }
    
    static func isLocationNotDetermined() -> Bool {
        guard CLLocationManager.locationServicesEnabled() else { return false }
        return sharedLocationManager.authorizationStatus == .notDetermined
    }
    
    static func isLocationDenied() -> Bool {
        guard CLLocationManager.locationServicesEnabled() else { return true }
        let status = sharedLocationManager.authorizationStatus
        return status == .denied || status == .restricted
    }
    
    static func requestLocationPermission() {
        sharedLocationManager.requestAlwaysAuthorization()
    }
    
    // MARK: - Bluetooth
    static func isBluetoothAuthorized() -> Bool {
        if #available(macOS 11.0, *) {
            return CBManager.authorization == .allowedAlways
        }
        return true
    }
    
    static func isBluetoothNotDetermined() -> Bool {
        if #available(macOS 11.0, *) {
            return CBManager.authorization == .notDetermined
        }
        return false
    }
    
    static func isBluetoothDenied() -> Bool {
        if #available(macOS 11.0, *) {
            let status = CBManager.authorization
            return status == .denied || status == .restricted
        }
        return false
    }
    
    static func checkBluetoothPermission() -> Bool {
        return isBluetoothAuthorized()
    }
    
    static func requestBluetoothPermission() {
        BluetoothPermissionDelegate.shared.requestPermission()
    }
    
    // MARK: - Microphone
    static func hasMicrophonePermission() -> Bool {
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }
    
    static func isMicrophoneNotDetermined() -> Bool {
        return AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined
    }
    
    static func isMicrophoneDenied() -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        return status == .denied || status == .restricted
    }
    
    static func requestMicrophonePermission(completion: ((Bool) -> Void)? = nil) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("MicrophoneAuthorizationChanged"), object: granted)
                completion?(granted)
            }
        }
    }
    
    // MARK: - Full Disk Access
    static func hasFullDiskAccess() -> Bool {
        let dbPath = NSString(string: "~/Library/DoNotDisturb/DB/Assertions.json").expandingTildeInPath
        if FileManager.default.isReadableFile(atPath: dbPath) {
            return true
        }
        let folderPath = NSString(string: "~/Library/DoNotDisturb/DB").expandingTildeInPath
        return FileManager.default.isReadableFile(atPath: folderPath)
    }
    
    // MARK: - Automation (Apple Events)
    static func ensureSystemEventsRunning(completion: (() -> Void)? = nil) {
        if !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.systemevents").isEmpty {
            completion?()
            return
        }
        let appURL = URL(fileURLWithPath: "/System/Library/CoreServices/System Events.app")
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        config.addsToRecentItems = false
        config.hides = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                completion?()
            }
        }
    }
    
    static func isAutomationAuthorized(for bundleIdentifier: String = "com.apple.systemevents") -> Bool {
        let targetDesc = NSAppleEventDescriptor(bundleIdentifier: bundleIdentifier)
        let perm = AEDeterminePermissionToAutomateTarget(targetDesc.aeDesc, typeWildCard, typeWildCard, false)
        return perm == noErr
    }
    
    static func isAutomationNotDetermined(for bundleIdentifier: String = "com.apple.systemevents") -> Bool {
        let targetDesc = NSAppleEventDescriptor(bundleIdentifier: bundleIdentifier)
        let perm = AEDeterminePermissionToAutomateTarget(targetDesc.aeDesc, typeWildCard, typeWildCard, false)
        return perm == -1744 || perm == -600
    }
    
    static func isAutomationDenied(for bundleIdentifier: String = "com.apple.systemevents") -> Bool {
        let targetDesc = NSAppleEventDescriptor(bundleIdentifier: bundleIdentifier)
        let perm = AEDeterminePermissionToAutomateTarget(targetDesc.aeDesc, typeWildCard, typeWildCard, false)
        return perm == -1743 || perm == -10827
    }
    
    static func requestAutomationPermission(for bundleIdentifier: String = "com.apple.systemevents", completion: ((Bool) -> Void)? = nil) {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Using the current dark mode status ensures setting dark mode is completely idempotent
            // (no visual change occurs), but because it is a mutation command to System Events,
            // macOS TCC intercepts it and displays the native Automation permission dialog!
            let isDark = DisplaySettingsManager.shared.isDarkMode
            let scriptSource = "tell application \"System Events\" to tell appearance preferences to set dark mode to \(isDark ? "true" : "false")"
            let script = NSAppleScript(source: scriptSource)
            var errorInfo: NSDictionary?
            let res = script?.executeAndReturnError(&errorInfo)
            
            let targetDesc = NSAppleEventDescriptor(bundleIdentifier: bundleIdentifier)
            let status = AEDeterminePermissionToAutomateTarget(targetDesc.aeDesc, typeWildCard, typeWildCard, false)
            let isAuthorized = (status == noErr || (res != nil && errorInfo == nil))
            
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                if let window = (NSApp.delegate as? AppDelegate)?.customDashboardWindow, window.isVisible {
                    window.makeKeyAndOrderFront(nil)
                }
                PermissionManager.shared.refresh()
                completion?(isAuthorized)
            }
        }
    }
    
    // MARK: - Settings Opener
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
        case "FullDisk":
            urlString += "?Privacy_AllFiles"
        default:
            break
        }
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
