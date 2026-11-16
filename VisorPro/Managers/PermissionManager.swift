import Foundation
import Combine
import AppKit

final class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    @Published var isBluetoothAuthorized: Bool = false
    @Published var isBluetoothNotDetermined: Bool = false
    @Published var isBluetoothDenied: Bool = false
    
    @Published var isLocationAuthorized: Bool = false
    @Published var isLocationNotDetermined: Bool = false
    @Published var isLocationDenied: Bool = false
    
    @Published var isMicrophoneAuthorized: Bool = false
    @Published var isMicrophoneNotDetermined: Bool = false
    @Published var isMicrophoneDenied: Bool = false
    
    @Published var isThemeAutomationAuthorized: Bool = false
    @Published var isThemeAutomationNotDetermined: Bool = false
    @Published var isThemeAutomationDenied: Bool = false
    
    @Published var isFinderAutomationAuthorized: Bool = false
    @Published var isFinderAutomationNotDetermined: Bool = false
    @Published var isFinderAutomationDenied: Bool = false
    
    @Published var isFullDiskAccessAuthorized: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        refresh()
        
        // Listen to application becoming active (e.g. returning from macOS System Settings)
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
            
        // Listen to Location authorization changes
        NotificationCenter.default.publisher(for: Notification.Name("LocationAuthorizationChanged"))
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
            
        // Listen to Bluetooth authorization changes
        NotificationCenter.default.publisher(for: Notification.Name("BluetoothAuthorizationChanged"))
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
            
        // Listen to Microphone authorization changes
        NotificationCenter.default.publisher(for: Notification.Name("MicrophoneAuthorizationChanged"))
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }
    
    func refresh() {
        let lAuthorized = PermissionHelper.hasLocationPermission()
        let lNotDet = PermissionHelper.isLocationNotDetermined()
        let lDenied = PermissionHelper.isLocationDenied()
        
        let bAuthorized = PermissionHelper.isBluetoothAuthorized()
        let bNotDet = PermissionHelper.isBluetoothNotDetermined()
        let bDenied = PermissionHelper.isBluetoothDenied()
        
        let mAuthorized = PermissionHelper.hasMicrophonePermission()
        let mNotDet = PermissionHelper.isMicrophoneNotDetermined()
        let mDenied = PermissionHelper.isMicrophoneDenied()
        
        let fAuthorized = PermissionHelper.hasFullDiskAccess()
        
        // Immediately publish synchronous permissions (zero flicker/delay for UI)
        self.isBluetoothAuthorized = bAuthorized
        self.isBluetoothNotDetermined = bNotDet
        self.isBluetoothDenied = bDenied
        
        self.isLocationAuthorized = lAuthorized
        self.isLocationNotDetermined = lNotDet
        self.isLocationDenied = lDenied
        
        self.isMicrophoneAuthorized = mAuthorized
        self.isMicrophoneNotDetermined = mNotDet
        self.isMicrophoneDenied = mDenied
        
        self.isFullDiskAccessAuthorized = fAuthorized
        
        let mgr = MediaKeyManager.shared
        
        // Sync Bluetooth
        if !bAuthorized {
            if mgr.enableBluetooth {
                mgr.enableBluetooth = false
            }
        } else {
            if UserDefaults.standard.object(forKey: "enableBluetooth") as? Bool ?? true {
                if !mgr.enableBluetooth {
                    mgr.enableBluetooth = true
                }
            }
        }
        
        // Sync Location
        if !lAuthorized {
            if mgr.enableWiFi {
                mgr.enableWiFi = false
            }
        } else {
            if UserDefaults.standard.object(forKey: "enableWiFi") as? Bool ?? true {
                if !mgr.enableWiFi {
                    mgr.enableWiFi = true
                }
            }
        }
        
        // Sync Microphone
        if !mAuthorized {
            if UserDefaults.standard.bool(forKey: "micShowVisualizer") {
                UserDefaults.standard.set(false, forKey: "micShowVisualizer")
            }
        }
        
        // Sync Full Disk Access (Focus Detailed Mode)
        if !fAuthorized {
            if UserDefaults.standard.bool(forKey: "focusDetailMode") {
                UserDefaults.standard.set(false, forKey: "focusDetailMode")
            }
        }
        
        // Background check for Apple Events (Automation) to keep UI responsive
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let tAuthorized = PermissionHelper.isAutomationAuthorized(for: "com.apple.systemevents")
            let tNotDet = PermissionHelper.isAutomationNotDetermined(for: "com.apple.systemevents")
            let tDenied = PermissionHelper.isAutomationDenied(for: "com.apple.systemevents")
            
            let fAuthorized = PermissionHelper.isAutomationAuthorized(for: "com.apple.finder")
            let fNotDet = PermissionHelper.isAutomationNotDetermined(for: "com.apple.finder")
            let fDenied = PermissionHelper.isAutomationDenied(for: "com.apple.finder")
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isThemeAutomationAuthorized = tAuthorized
                self.isThemeAutomationNotDetermined = tNotDet
                self.isThemeAutomationDenied = tDenied
                
                self.isFinderAutomationAuthorized = fAuthorized
                self.isFinderAutomationNotDetermined = fNotDet
                self.isFinderAutomationDenied = fDenied
            }
        }
    }
    
    func requestBluetoothPermission() {
        PermissionHelper.requestBluetoothPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refresh()
        }
    }
    
    func requestLocationPermission() {
        PermissionHelper.requestLocationPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refresh()
        }
    }
    
    func requestMicrophonePermission(completion: ((Bool) -> Void)? = nil) {
        PermissionHelper.requestMicrophonePermission { [weak self] granted in
            self?.refresh()
            completion?(granted)
        }
    }
    
    func requestThemeAutomationPermission() {
        PermissionHelper.requestAutomationPermission(for: "com.apple.systemevents") { [weak self] _ in
            self?.refresh()
        }
    }
    
    func requestFinderAutomationPermission(completion: ((Bool) -> Void)? = nil) {
        PermissionHelper.requestAutomationPermission(for: "com.apple.finder") { [weak self] granted in
            self?.refresh()
            completion?(granted)
        }
    }
}
