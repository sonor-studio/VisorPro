import Foundation
import CoreWLAN

class WiFiObserver: NSObject, CWEventDelegate {
    private weak var manager: MediaKeyManager?
    private var client: CWWiFiClient?
    private var lastSSID: String?
    
    init(manager: MediaKeyManager) {
        self.manager = manager
        super.init()
        
        startObserving()
    }
    
    func startObserving() {
        self.client = CWWiFiClient.shared()
        self.client?.delegate = self
        
        do {
            try self.client?.startMonitoringEvent(with: .ssidDidChange)
            try self.client?.startMonitoringEvent(with: .linkDidChange)
            try self.client?.startMonitoringEvent(with: .powerDidChange)
            
            // Pobierz początkowy SSID żeby mieć punkt odniesienia
            self.lastSSID = getSSID()
        } catch {
            print("Błąd podczas uruchamiania monitorowania Wi-Fi: \(error)")
        }
    }
    
    // Używamy networksetup jako obejścia restrykcyjnych wymogów Location Services od macOS 14.4+
    private func getSSID() -> String? {
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
                        return parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        } catch {}
        return nil
    }
    
    func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
        checkWiFiState()
    }
    
    func linkDidChangeForWiFiInterface(withName interfaceName: String) {
        checkWiFiState()
    }
    
    func powerStateDidChangeForWiFiInterface(withName interfaceName: String) {
        checkWiFiState()
    }
    
    private func checkWiFiState() {
        guard let manager = manager, !manager.useSystemOSD else { return }
        
        let currentSSID = getSSID()
        
        DispatchQueue.main.async {
            if let current = currentSSID {
                if let last = self.lastSSID, last != current {
                    manager.lastAction = "Zmieniono Wi-Fi na: \(current)"
                } else if self.lastSSID == nil {
                    manager.lastAction = "Połączono z Wi-Fi: \(current)"
                }
                self.lastSSID = current
            } else {
                if self.lastSSID != nil {
                    manager.lastAction = "Odłączono od Wi-Fi 🌐"
                    self.lastSSID = nil
                }
            }
        }
    }
}
