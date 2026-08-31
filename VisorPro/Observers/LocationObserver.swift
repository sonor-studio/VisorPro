import Foundation
import AppKit

class LocationObserver {
    private var process: Process?
    private var pipe: Pipe?
    weak var manager: MediaKeyManager?
    
    init(manager: MediaKeyManager) {
        self.manager = manager
    }
    
    private var lastTriggerTime: Date = .distantPast
    
    private func extractAppName(from logLine: String) -> String? {
        if let clientRange = logLine.range(of: "\"Client\":\"") {
            let sub = logLine[clientRange.upperBound...]
            if let endRange = sub.range(of: "\"") {
                let clientStr = String(sub[..<endRange.lowerBound])
                let parts = clientStr.split(separator: ":")
                if parts.count >= 2 {
                    let identifierPart = String(parts[1])
                    var bundleId = ""
                    var isSystem = false
                    
                    if identifierPart.hasPrefix("i") {
                        bundleId = String(identifierPart.dropFirst())
                    } else if identifierPart.hasPrefix("p") {
                        isSystem = true
                        bundleId = "SystemPath"
                    }
                    
                    if !bundleId.isEmpty {
                        if !isSystem, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                            let path = url.path
                            
                            if path.hasPrefix("/System/Library/") || 
                               path.hasPrefix("/usr/") || 
                               path.contains("CoreServices") || 
                               path.contains("/Utilities/") {
                                return "System Services"
                            }
                            
                            return FileManager.default.displayName(atPath: path)
                                .replacingOccurrences(of: ".app", with: "")
                        }
                        
                        return "System Services"
                    }
                }
            }
        }
        return nil
    }
    
    func startObserving() {
        process = Process()
        process?.launchPath = "/usr/bin/log"
        process?.arguments = ["stream", "--predicate", "process == 'locationd'"]
        
        pipe = Pipe()
        process?.standardOutput = pipe
        
        pipe?.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            let data = fileHandle.availableData
            guard data.count > 0, let output = String(data: data, encoding: .utf8) else { return }
            
            if output.localizedCaseInsensitiveContains("authorized for location") || 
               output.localizedCaseInsensitiveContains("sending location to client") ||
               (output.localizedCaseInsensitiveContains("client") && output.localizedCaseInsensitiveContains("starting now")) {
                
                guard let appName = self?.extractAppName(from: output), !appName.isEmpty else { return }
                guard let manager = self?.manager else { return }
                
                var shouldShow = true
                if appName == "System Services" {
                    shouldShow = manager.locationShowSystemServices
                } else if appName == "Weather" || appName == "Pogoda" {
                    shouldShow = manager.locationShowWeather
                } else if appName == "Maps" || appName == "Mapy" {
                    shouldShow = manager.locationShowMaps
                } else if appName == "Safari" {
                    shouldShow = manager.locationShowSafari
                } else {
                    shouldShow = manager.locationShowOtherApps
                }
                
                guard shouldShow else { return }
                
                let now = Date()
                if let last = self?.lastTriggerTime, now.timeIntervalSince(last) > 3.0 {
                    self?.lastTriggerTime = now
                    manager.triggerLocationIndicator(appName: appName)
                }
            }
        }
        
        do {
            try process?.run()
        } catch {
            LogManager.shared.log("Error in LocationObserver.swift: \(error)", level: "ERROR")
        }
    }
    
    func stopObserving() {
        process?.terminate()
        process = nil
        pipe = nil
    }
    
    deinit {
        stopObserving()
    }
}
