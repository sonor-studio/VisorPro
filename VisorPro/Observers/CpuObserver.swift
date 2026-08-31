import Foundation
import AppKit
import Combine
import SwiftUI
import SMCKit

class CpuObserver: ObservableObject {
    static let shared = CpuObserver()
    
    private var timer: Timer?
    
    // Zapiszemy tu klucz, który zadziała na danym Macu
    private var workingSensorKey: String? 
    
    // Lista popularnych czujników. Najpierw Apple Silicon, potem klucze z układów Intel
    private let sensorKeys = [
        "Tp09", "Tp05", "Tp01", // M-Series (Apple Silicon)
        "TC0P", "TC0D", "TC0E", "TC0F" // Intel (Proximity, Die, etc.)
    ]
    
    private init() {
        startObserving()
    }
    
    // Helper do konwersji Stringa na FourCharCode (UInt32), którego wymaga biblioteka SMCKit
    private func toFourCharCode(_ str: String) -> UInt32 {
        var result: UInt32 = 0
        for char in str.utf8 {
            result = (result << 8) + UInt32(char)
        }
        return result
    }
    
    private func startObserving() {
        // Uruchamiamy odpytywanie co 3 sekundy
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.updateTemperature()
        }
        updateTemperature()
    }
    
    private func updateTemperature() {
        // Uruchamiamy zadanie asynchroniczne, ponieważ biblioteka korzysta z aktorów (async/await)
        Task {
            var currentTemp = 45.0 // Wartość domyślna w razie błędu odczytu
            
            do {
                if let knownKey = workingSensorKey {
                    // Jeśli już wiemy, który czujnik działa na tym Macu, używamy go od razu
                    let temp: Float = try await SMCKit.shared.read(toFourCharCode(knownKey))
                    currentTemp = Double(temp)
                } else {
                    // Pierwsze uruchomienie: szukamy działającego czujnika
                    for key in sensorKeys {
                        do {
                            let temp: Float = try await SMCKit.shared.read(toFourCharCode(key))
                            if temp > 10.0 { // Upewniamy się, że odczyt jest sensowny (nie 0.0)
                                workingSensorKey = key
                                currentTemp = Double(temp)
                                break
                            }
                        } catch {
                            // Ten czujnik nie istnieje na tym Macu, próbujemy następny
                            continue
                        }
                    }
                }
            } catch {
                workingSensorKey = nil // W razie awarii resetujemy klucz, by poszukał go ponownie
            }
            
            // Wracamy na wątek główny aby zaktualizować UI
            await MainActor.run {
                MediaKeyManager.shared.triggerCpuTempOverlay(temp: currentTemp)
            }
            self.fetchTopProcesses()
        }
    }

        private func fetchTopProcesses() {
        DispatchQueue.global(qos: .background).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/top")
            task.arguments = ["-l", "2", "-n", "10", "-o", "cpu", "-stats", "pid,cpu,command"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            do {
                try task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    // top -l 2 zwraca dwa odczyty. Interesuje nas ten drugi, bo pierwszy jest zazwyczaj niedokładny.
                    let components = output.components(separatedBy: "PID    %CPU COMMAND")
                    guard components.count >= 3, let lastBlock = components.last else { return }
                    
                    let lines = lastBlock.components(separatedBy: .newlines)
                    var processes: [(name: String, cpuPercent: Double, icon: NSImage?)] = []
                    
                    for line in lines {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.isEmpty { continue }
                        
                        let parts = trimmed.components(separatedBy: CharacterSet.whitespaces).filter { !$0.isEmpty }
                        guard parts.count >= 3 else { continue }
                        
                        if let pid = Int32(parts[0]), let pcpu = Double(parts[1]) {
                            if pcpu > 1.0 { // Pomijamy procesy < 1%
                                var name = parts[2...].joined(separator: " ")
                                var icon: NSImage? = nil
                                
                                if let app = NSRunningApplication(processIdentifier: pid), let localized = app.localizedName, !localized.isEmpty {
                                    name = localized
                                    icon = app.icon
                                    if name.contains("Safari") && (icon == nil || name == "Safari Web Content") {
                                        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
                                            icon = NSWorkspace.shared.icon(forFile: url.path)
                                        }
                                    }
                                } else {
                                    if name.hasPrefix("com.apple.WebKit.") {
                                        name = name.replacingOccurrences(of: "com.apple.WebKit.", with: "Safari ")
                                        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
                                            icon = NSWorkspace.shared.icon(forFile: url.path)
                                        }
                                    } else if name.hasPrefix("com.apple.") {
                                        name = name.replacingOccurrences(of: "com.apple.", with: "Apple ")
                                        icon = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: nil)
                                    } else if name == "kernel_task" || name == "WindowServer" || name == "launchd" {
                                        icon = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: nil)
                                    } else if name == "top" {
                                        continue // Nie pokazujemy samego narzędzia diagnostycznego
                                    } else {
                                        icon = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: nil)
                                    }
                                }
                                
                                processes.append((name: name, cpuPercent: pcpu, icon: icon))
                            }
                        }
                    }
                    
                    processes.sort { $0.cpuPercent > $1.cpuPercent }
                    let topList = Array(processes.prefix(5))
                    
                    DispatchQueue.main.async {
                        MediaKeyManager.shared.cpuTopProcesses = topList
                    }
                }
            } catch {
                print("Błąd top w CPU: \(error)")
            }
        }
    }
}
