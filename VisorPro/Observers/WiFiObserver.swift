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
        self.lastSSID = CWWiFiClient.shared().interface()?.ssid()
        self.lastIsConnected = self.lastSSID != nil
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
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
    
    private var isFetchingNetworkSetup: Bool = false
    
    @objc private func pollWiFi() {
        guard let interface = CWWiFiClient.shared().interface() else { return }
        
        let powerOn = interface.powerOn()
        if !powerOn {
            inactiveCounter = 0
            handleFinalState(isConnected: false, ssid: nil)
            return
        }
        
        if let ssid = interface.ssid(), !ssid.isEmpty {
            inactiveCounter = 0
            cachedNetworkSetupSSID = ssid
            handleFinalState(isConnected: true, ssid: ssid)
        } else {
            // Asynchronous fetch via networksetup to avoid blocking main thread
            if Date().timeIntervalSince(lastNetworkSetupPoll) > 3.0 && !isFetchingNetworkSetup {
                isFetchingNetworkSetup = true
                lastNetworkSetupPoll = Date()
                
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
                    process.arguments = ["-getairportnetwork", "en0"]
                    let pipe = Pipe()
                    process.standardOutput = pipe
                    
                    var foundSSID: String? = nil
                    do {
                        try process.run()
                        process.waitUntilExit()
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        if let output = String(data: data, encoding: .utf8) {
                            if output.contains("Current Wi-Fi Network:") {
                                let parts = output.components(separatedBy: "Current Wi-Fi Network: ")
                                if parts.count > 1 {
                                    let parsed = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                                    if parsed != "null" && !parsed.isEmpty {
                                        foundSSID = parsed
                                    }
                                }
                            }
                        }
                    } catch {
                        LogManager.shared.log("Error in WiFiObserver.swift: \(error)", level: "ERROR")
                    }
                    
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.isFetchingNetworkSetup = false
                        self.cachedNetworkSetupSSID = foundSSID
                        self.processSSIDResult(foundSSID)
                    }
                }
            } else {
                // Use cached result while fetching or waiting
                processSSIDResult(cachedNetworkSetupSSID)
            }
        }
    }
    
    private func processSSIDResult(_ ssid: String?) {
        if let validSSID = ssid, !validSSID.isEmpty {
            inactiveCounter = 0
            handleFinalState(isConnected: true, ssid: validSSID)
        } else {
            inactiveCounter += 1
            if inactiveCounter >= 10 { // 5 sekundy "pustego" stanu
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
