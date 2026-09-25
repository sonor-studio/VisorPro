import AppKit
import Foundation
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
        // Poll every 5 seconds
        timer = Timer.scheduledTimerInCommonModes(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateTemperature()
        }
        updateTemperature()
    }
    
    private func updateTemperature() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var currentTemp = 45.0 // Default value in case of read error
            
            do {
                if let knownKey = self.workingSensorKey {
                    // If we already know which sensor works on this Mac, use it directly
                    let temp: Float = try SMCKit.shared.read(self.toFourCharCode(knownKey))
                    currentTemp = Double(temp)
                } else {
                    // First run: find a working sensor
                    for key in self.sensorKeys {
                        do {
                            let temp: Float = try SMCKit.shared.read(self.toFourCharCode(key))
                            if temp > 10.0 { // Ensure the reading is reasonable (not 0.0)
                                self.workingSensorKey = key
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
                self.workingSensorKey = nil // Reset key on failure so it searches again next time
            }
            
            // Update UI on main thread
            DispatchQueue.main.async {
                MediaKeyManager.shared.triggerCpuTempOverlay(temp: currentTemp)
            }
            self.fetchTopProcesses()
        }
    }

        private func fetchTopProcesses() {
        DispatchQueue.global(qos: .background).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/ps")
            task.arguments = ["-c", "-ax", "-o", "pid,pcpu,comm"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            do {
                try task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let lines = output.components(separatedBy: .newlines).dropFirst()
                    var processes: [(name: String, cpuPercent: Double, icon: NSImage?)] = []
                    
                    for line in lines {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.isEmpty { continue }
                        
                        let parts = trimmed.components(separatedBy: CharacterSet.whitespaces).filter { !$0.isEmpty }
                        guard parts.count >= 3 else { continue }
                        
                        if let pid = Int32(parts[0]), let pcpu = Double(parts[1]) {
                            if pcpu > 1.0 { // Skip processes using < 1% CPU
                                var name = parts[2...].joined(separator: " ")
                                let icon: NSImage? = ProcessIconCache.icon(for: name) {
                                    var resolvedIcon: NSImage? = nil
                                    if let app = NSRunningApplication(processIdentifier: pid), let localized = app.localizedName, !localized.isEmpty {
                                        name = localized
                                        resolvedIcon = app.icon
                                        if name.contains("Safari") && (resolvedIcon == nil || name == "Safari Web Content") {
                                            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
                                                resolvedIcon = NSWorkspace.shared.icon(forFile: url.path)
                                            }
                                        }
                                    } else {
                                        if name.hasPrefix("com.apple.WebKit.") {
                                            name = name.replacingOccurrences(of: "com.apple.WebKit.", with: "Safari ")
                                            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
                                                resolvedIcon = NSWorkspace.shared.icon(forFile: url.path)
                                            }
                                        } else if name.hasPrefix("com.apple.") {
                                            name = name.replacingOccurrences(of: "com.apple.", with: "Apple ")
                                            resolvedIcon = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: nil)
                                        } else if name == "kernel_task" || name == "WindowServer" || name == "launchd" {
                                            resolvedIcon = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: nil)
                                        } else if name != "top" {
                                            resolvedIcon = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: nil)
                                        }
                                    }
                                    return resolvedIcon
                                }
                                
                                if name == "top" { continue }
                                
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

class ProcessIconCache {
    static var cache: [String: NSImage] = [:]
    private static let lock = NSLock()
    
    static func icon(for name: String, resolve: () -> NSImage?) -> NSImage? {
        lock.lock()
        if let cached = cache[name] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        
        let img = resolve()
        if let img = img {
            lock.lock()
            cache[name] = img
            lock.unlock()
        }
        return img
    }
}
