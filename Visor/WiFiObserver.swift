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
    private var inactiveCounter: Int = 0
    
    private var pathMonitor: NWPathMonitor?
    private let pathQueue = DispatchQueue(label: "PathMonitorQueue")
    private var isCurrentlyHotspot: Bool = false
    
    private var lastNetworkSetupPoll: Date = .distantPast
    private var cachedNetworkSetupSSID: String?
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
            if self.locationManager?.authorizationStatus == .notDetermined {
                self.locationManager?.requestAlwaysAuthorization()
            }
        }
        
        startObserving()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorized {
            self.pollWiFi()
        }
    }
    
    func startObserving() {
        self.lastSSID = getSSIDThrottled()
        self.lastIsConnected = self.lastSSID != nil
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                self.pollWiFi()
            }
            
            self.pathMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
            self.pathMonitor?.pathUpdateHandler = { [weak self] path in
                let expensive = path.isExpensive
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if self.isCurrentlyHotspot != expensive {
                        self.isCurrentlyHotspot = expensive
                        // Jeśli odświeżyło się z opóźnieniem, przekaż to w locie do aktywnej nakładki!
                        if self.lastIsConnected {
                            self.manager?.wiFiIsHotspot = expensive
                        }
                    }
                }
            }
            self.pathMonitor?.start(queue: self.pathQueue)
        }
    }
    
    @objc private func pollWiFi() {
        guard let interface = CWWiFiClient.shared().interface() else { return }
        
        let powerOn = interface.powerOn()
        if !powerOn {
            inactiveCounter = 0
            handleFinalState(isConnected: false, ssid: nil)
            return
        }
        
        var currentSSID = interface.ssid()
        if currentSSID == nil || currentSSID!.isEmpty {
            currentSSID = getSSIDThrottled()
        }
        
        if let validSSID = currentSSID, !validSSID.isEmpty {
            inactiveCounter = 0
            handleFinalState(isConnected: true, ssid: validSSID)
        } else {
            inactiveCounter += 1
            if inactiveCounter >= 8 { // 4 sekundy "pustego" stanu (np. podczas przełączania/DHCP) = dopiero teraz Rozłączono
                handleFinalState(isConnected: false, ssid: nil)
            }
        }
    }
    
    private func getSSIDThrottled() -> String? {
        if Date().timeIntervalSince(lastNetworkSetupPoll) < 3.0 {
            return cachedNetworkSetupSSID
        }
        lastNetworkSetupPoll = Date()
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = ["-getairportnetwork", "en0"]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                if output.contains("Current Wi-Fi Network:") {
                    let parts = output.components(separatedBy: "Current Wi-Fi Network: ")
                    if parts.count > 1 {
                        let ssid = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        if ssid != "null" && !ssid.isEmpty {
                            cachedNetworkSetupSSID = ssid
                            return ssid
                        }
                    }
                }
            }
        } catch {}
        
        cachedNetworkSetupSSID = nil
        return nil
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
            } else {
                let networkName = self.lastSSID ?? "Wi-Fi"
                manager.lastAction = "Disconnected from Wi-Fi"
                manager.triggerWiFiIndicator(ssid: networkName, isConnected: false, isHotspot: false)
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
