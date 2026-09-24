import Foundation
import AppKit
import Combine
import SwiftUI
import SMCKit

class CpuObserver: ObservableObject {
    static let shared = CpuObserver()
    
    private var timer: Timer?
    
    // We will save the key that works on a given Mac here
    private var workingSensorKey: String? 
    
    // List of popular sensors. Apple Silicon first, then Intel chips
    private let sensorKeys = [
        "Tp09", "Tp05", "Tp01", // M-Series (Apple Silicon)
        "TC0P", "TC0D", "TC0E", "TC0F" // Intel (Proximity, Die, etc.)
    ]
    
    private init() {
        startObserving()
    }
    
    // Helper for converting String to FourCharCode (UInt32) required by SMCKit library
    private func toFourCharCode(_ str: String) -> UInt32 {
        var result: UInt32 = 0
        for char in str.utf8 {
            result = (result << 8) + UInt32(char)
        }
        return result
    }
    
    private func startObserving() {
        // Poll every 3 seconds
        timer = Timer.scheduledTimerInCommonModes(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.updateTemperature()
        }
        updateTemperature()
    }
    
    private func updateTemperature() {
        // Run asynchronous task because SMCKit uses actors (async/await)
        Task {
            var currentTemp = 45.0 // Default value in case of read error
            
            do {
                if let knownKey = workingSensorKey {
                    // If we already know which sensor works on this Mac, use it directly
                    let temp: Float = try SMCKit.shared.read(toFourCharCode(knownKey))
                    currentTemp = Double(temp)
                } else {
                    // First run: find a working sensor
                    for key in sensorKeys {
                        do {
                            let temp: Float = try SMCKit.shared.read(toFourCharCode(key))
                            if temp > 10.0 { // Ensure the reading is reasonable (not 0.0)
                                workingSensorKey = key
                                currentTemp = Double(temp)
                                break
                            }
                        } catch {
                            // This sensor doesn't exist on this Mac, try the next one
                            continue
                        }
                    }
                }
            } catch {
                workingSensorKey = nil // Reset key on failure so it searches again next time
            }
            
            // Update UI on main thread
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
                    // top -l 2 returns two samples. We are interested in the second one, as the first is usually inaccurate.
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
                            if pcpu > 1.0 { // Skip processes using < 1% CPU
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
                                        continue // Hide the diagnostic tool itself
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
            }
        }
    }
}
