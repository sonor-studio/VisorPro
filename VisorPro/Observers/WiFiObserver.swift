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
    private let pollQueue = DispatchQueue(label: "com.visorpro.wifi-poll", qos: .userInitiated)
    private var isCurrentlyHotspot: Bool = false
    private var networkIsSatisfied: Bool = false
    
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
            pollQueue.async { [weak self] in
                self?.pollWiFi()
            }
        } else if status == .denied || status == .restricted {
            DispatchQueue.main.async { [weak self] in
                self?.manager?.enableWiFi = false
            }
        }
    }
    
    func canUseSSIDAPI() -> Bool {
        return PermissionHelper.hasLocationPermission()
    }

    func startObserving() {
        pollQueue.async { [weak self] in
            guard let self = self else { return }
            if self.canUseSSIDAPI() {
                self.lastSSID = CWWiFiClient.shared().interface()?.ssid()
            } else {
                self.lastSSID = nil
            }
            // Zgadujemy początkowy stan na podstawie SSID, resztę ogarnie pathMonitor
            self.lastIsConnected = self.lastSSID != nil 
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.timer = Timer.scheduledTimerInCommonModes(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
                self?.pollQueue.async {
                    self?.pollWiFi()
                }
            }
            self.pathMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
            self.pathMonitor?.pathUpdateHandler = { [weak self] path in
                let expensive = path.isExpensive
                let isSatisfied = path.status == .satisfied
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    let wasSatisfied = self.networkIsSatisfied
                    self.networkIsSatisfied = isSatisfied
                    
                    if self.isCurrentlyHotspot != expensive {
                        self.isCurrentlyHotspot = expensive
                        if self.lastIsConnected && isSatisfied {
                            self.manager?.wiFiIsHotspot = expensive
                            self.lastWasHotspot = expensive
                        } else if self.lastIsConnected && !isSatisfied {
                            self.manager?.wiFiIsHotspot = expensive
                        }
                    }
                    
                    if wasSatisfied != isSatisfied {
                        self.pollQueue.async {
                            self.pollWiFi()
                        }
                    }
                }
            }
            self.pathMonitor?.start(queue: self.pathQueue)
        }
    }
    
    @objc private func pollWiFi() {
        guard let manager = self.manager else { return }
        
        let interface = CWWiFiClient.shared().interface()
        var powerOn = interface?.powerOn() ?? true
        
        if self.networkIsSatisfied {
            powerOn = true
        }
        
        Logger.log("pollWiFi: powerOn=\(powerOn), networkIsSatisfied=\(self.networkIsSatisfied)")
        
        if !powerOn {
            inactiveCounter = 0
            handleFinalState(isConnected: false, ssid: nil, isEnabled: manager.enableWiFi)
            return
        }
        
        var connected = false
        var currentSSID: String? = nil
        
        if canUseSSIDAPI() {
            if let ssid = interface?.ssid(), !ssid.isEmpty {
                connected = true
                currentSSID = ssid
            } else {
                // Gdy brakuje SSID, weryfikujemy stan za pomocą NWPathMonitor
                connected = self.networkIsSatisfied
            }
        } else {
            connected = self.networkIsSatisfied
        }
        
        Logger.log("pollWiFi: connected=\(connected), currentSSID=\(currentSSID ?? "nil")")
        
        if connected {
            inactiveCounter = 0
            // Zabezpieczenie przed błędem "Switched to: Unknown Wi-Fi" podczas flappingu
            if currentSSID == nil && self.lastIsConnected {
                currentSSID = self.lastSSID
            }
            handleFinalState(isConnected: true, ssid: currentSSID, isEnabled: manager.enableWiFi)
        } else {
            // Skoro system (NWPathMonitor) twierdzi że ścieżka padła,
            // to nie jest to chwilowy flapping. Rozłączamy natychmiast.
            if !self.networkIsSatisfied {
                inactiveCounter = 5
            } else {
                inactiveCounter += 1
            }
            
            Logger.log("pollWiFi: inactiveCounter=\(inactiveCounter)")
            if inactiveCounter >= 5 {
                handleFinalState(isConnected: false, ssid: nil, isEnabled: manager.enableWiFi)
            }
        }
    }
    
    private func handleFinalState(isConnected: Bool, ssid: String?, isEnabled: Bool) {
        guard let manager = manager else { return }
        if manager.useSystemOSD {
            Logger.log("handleFinalState: useSystemOSD is true, returning")
            return
        }
        
        if isInitialLoad {
            self.lastIsConnected = isConnected
            self.lastSSID = ssid
            Logger.log("handleFinalState: isInitialLoad, returning")
            return
        }
        
        let connectionStateChanged = isConnected != self.lastIsConnected
        let ssidChanged = ssid != self.lastSSID
        
        Logger.log("handleFinalState: isConnected=\(isConnected), ssid=\(ssid ?? "nil") | lastIsConnected=\(self.lastIsConnected), lastSSID=\(self.lastSSID ?? "nil") | connChanged=\(connectionStateChanged), ssidChanged=\(ssidChanged)")
        
        if !connectionStateChanged && !ssidChanged {
            Logger.log("handleFinalState: no change, returning")
            return
        }
        
        if isEnabled {
            Logger.log("handleFinalState: triggerWiFiIndicator will be called!")
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if isConnected {
                    let networkName = ssid ?? "Unknown Wi-Fi"
                    let ssidChangedLocal = networkName != self.lastSSID
                    
                    if self.lastIsConnected && ssidChangedLocal && self.lastSSID != nil {
                        manager.lastAction = "Switched to: \(networkName)"
                    } else {
                        manager.lastAction = "Connected to: \(networkName)"
                    }
                    manager.triggerWiFiIndicator(ssid: networkName, isConnected: true, isHotspot: self.isCurrentlyHotspot)
                } else {
                    let networkName = self.lastSSID ?? "Wi-Fi"
                    let wasHotspot = self.lastWasHotspot
                    manager.lastAction = "Disconnected from \(wasHotspot ? "Hotspot" : "Wi-Fi")"
                    manager.triggerWiFiIndicator(ssid: networkName, isConnected: false, isHotspot: wasHotspot)
                }
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if isConnected {
                self.lastWasHotspot = self.isCurrentlyHotspot
            } else {
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
