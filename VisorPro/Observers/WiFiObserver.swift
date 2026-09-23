import Foundation
import Network
import CoreLocation
import CoreWLAN

class WiFiObserver: NSObject, CLLocationManagerDelegate {
    private weak var manager: MediaKeyManager?
    private var locationManager: CLLocationManager?
    
    private var timer: Timer?
    private var lastSSID: String?
    private var lastIsConnected: Bool = false
    private var lastWasHotspot: Bool = false
    private var inactiveCounter: Int = 0
    
    private var pathMonitor: NWPathMonitor?
    private let pathQueue = DispatchQueue(label: "PathMonitorQueue")
    private var isCurrentlyHotspot: Bool = false
    
    private var isInitialLoad: Bool = true
    
    init(manager: MediaKeyManager) {
        self.manager = manager
        super.init()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isInitialLoad = false
        }
        
        DispatchQueue.main.async {
            self.locationManager = CLLocationManager()
            self.locationManager?.delegate = self
        }
        
        startObserving()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status != .denied && status != .restricted && status != .notDetermined {
            self.pollWiFi()
        }
    }
    
    func canUseSSIDAPI() -> Bool {
        if #available(macOS 14.0, *) {
            let status = locationManager?.authorizationStatus ?? .notDetermined
            return status != .notDetermined && status != .denied && status != .restricted
        }
        return true
    }

    func startObserving() {
        if canUseSSIDAPI() {
            self.lastSSID = CWWiFiClient.shared().interface()?.ssid()
        } else {
            self.lastSSID = nil
        }
        self.lastIsConnected = self.lastSSID != nil
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.timer = Timer.scheduledTimerInCommonModes(withTimeInterval: 1.5, repeats: true) { _ in
                self.pollWiFi()
            }
            self.pathMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
            self.pathMonitor?.pathUpdateHandler = { [weak self] path in
                let expensive = path.isExpensive
                let isSatisfied = path.status == .satisfied
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if self.isCurrentlyHotspot != expensive {
                        self.isCurrentlyHotspot = expensive
                        if self.lastIsConnected && isSatisfied {
                            self.manager?.wiFiIsHotspot = expensive
                            self.lastWasHotspot = expensive
                        } else if self.lastIsConnected && !isSatisfied {
                            self.manager?.wiFiIsHotspot = expensive
                        }
                    }
                }
            }
            self.pathMonitor?.start(queue: self.pathQueue)
        }
    }
    
    @objc private func pollWiFi() {
        guard let manager = self.manager, manager.enableWiFi else { return }

        let interface = CWWiFiClient.shared().interface()
        
        let powerOn = interface?.powerOn() ?? true
        if !powerOn {
            inactiveCounter = 0
            handleFinalState(isConnected: false, ssid: nil)
            return
        }
        
        if canUseSSIDAPI(), let ssid = interface?.ssid(), !ssid.isEmpty {
            inactiveCounter = 0
            handleFinalState(isConnected: true, ssid: ssid)
        } else {
            // Location access denied or no network connected
            processSSIDResult(nil)
        }
    }
    
    private func processSSIDResult(_ ssid: String?) {
        if let validSSID = ssid, !validSSID.isEmpty {
            inactiveCounter = 0
            handleFinalState(isConnected: true, ssid: validSSID)
        } else {
            inactiveCounter += 1
            if inactiveCounter >= 10 { // 5 seconds of "empty" state
                handleFinalState(isConnected: false, ssid: nil)
            }
        }
    }
    
    private func handleFinalState(isConnected: Bool, ssid: String?) {
        guard let manager = manager, !manager.useSystemOSD else { return }
        
        if isInitialLoad {
            self.lastIsConnected = isConnected
            self.lastSSID = ssid
            return
        }
        
        let connectionStateChanged = isConnected != self.lastIsConnected
        let ssidChanged = ssid != self.lastSSID
        
        if !connectionStateChanged && !ssidChanged {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if isConnected {
                let networkName = ssid ?? "Unknown Wi-Fi"
                let ssidChanged = networkName != self.lastSSID
                
                if self.lastIsConnected && ssidChanged && self.lastSSID != nil {
                    manager.lastAction = "Switched to: \(networkName)"
                } else {
                    manager.lastAction = "Connected to: \(networkName)"
                }
                manager.triggerWiFiIndicator(ssid: networkName, isConnected: true, isHotspot: self.isCurrentlyHotspot)
                self.lastWasHotspot = self.isCurrentlyHotspot
            } else {
                let networkName = self.lastSSID ?? "Wi-Fi"
                let wasHotspot = self.lastWasHotspot
                manager.lastAction = "Disconnected from \(wasHotspot ? "Hotspot" : "Wi-Fi")"
                manager.triggerWiFiIndicator(ssid: networkName, isConnected: false, isHotspot: wasHotspot)
                self.lastWasHotspot = false
            }
            
            self.lastIsConnected = isConnected
            if isConnected {
                self.lastSSID = ssid
            } else {
                self.lastSSID = nil
            }
        }
    }
}
