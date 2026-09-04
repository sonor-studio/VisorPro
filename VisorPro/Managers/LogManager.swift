import Foundation
import AppKit

class LogManager {
    static let shared = LogManager()
    
    private let logFileURL: URL
    
    private init() {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportURL = urls[0].appendingPathComponent("VisorPro", isDirectory: true)
        
        if !fileManager.fileExists(atPath: appSupportURL.path) {
            try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        logFileURL = appSupportURL.appendingPathComponent("session_logs.txt")
        
        // Read current content and handle trimming if > 1MB
        var currentContent = ""
        if fileManager.fileExists(atPath: logFileURL.path) {
            if let attributes = try? fileManager.attributesOfItem(atPath: logFileURL.path),
               let fileSize = attributes[.size] as? UInt64,
               fileSize > 1024 * 1024 { // 1 MB
                if let content = try? String(contentsOf: logFileURL, encoding: .utf8) {
                    let lines = content.split(separator: "\n")
                    currentContent = lines.suffix(1000).joined(separator: "\n") + "\n"
                }
            } else {
                currentContent = (try? String(contentsOf: logFileURL, encoding: .utf8)) ?? ""
            }
        }
        
        // Generate Device Info
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var cpuInfo = "Unknown CPU"
        if size > 0 {
            var machine = [CChar](repeating: 0, count: size)
            sysctlbyname("machdep.cpu.brand_string", &machine, &size, nil, 0)
            cpuInfo = String(cString: machine)
        }
        
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        let deviceInfoHeader = """
        ========================================
        DEVICE INFORMATION
        ========================================
        OS: \(osVersion)
        Processor: \(cpuInfo)
        App Version: \(appVersion) (\(buildVersion))
        ========================================
        """
        
        // Ensure device info is at the very top
        if !currentContent.hasPrefix("========================================\nDEVICE INFORMATION") {
            // Remove any old device info block if it got pushed down (e.g. after trimming)
            if let range = currentContent.range(of: "========================================\nDEVICE INFORMATION\n========================================\n.*?========================================\n", options: .regularExpression) {
                currentContent.removeSubrange(range)
            }
            // Trim leading newlines from current content
            currentContent = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
            if !currentContent.isEmpty {
                currentContent = "\n\n" + currentContent
            }
            currentContent = deviceInfoHeader + currentContent
        }
        
        // Append new session marker
        let sessionMarker = "\n\n========================================\nNEW SESSION STARTED\n========================================\n"
        currentContent += sessionMarker
        
        // Write back to file
        try? currentContent.write(to: logFileURL, atomically: true, encoding: .utf8)
        
        log("Application launched")
    }
    
    func log(_ message: String, level: String = "INFO", file: String = #file, function: String = #function, line: Int = #line) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(timestamp)] [\(level)] [\(fileName):\(line) \(function)] \(message)\n"
        
        if let data = logMessage.data(using: .utf8) {
            if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                if #available(macOS 10.15.4, *) {
                    _ = try? fileHandle.seekToEnd()
                    _ = try? fileHandle.write(contentsOf: data)
                } else {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            } else {
                _ = try? data.write(to: logFileURL)
            }
        }
        // Print to Xcode console for testing
        print(logMessage, terminator: "")
    }
    
    func getLogs() -> String {
        return (try? String(contentsOf: logFileURL, encoding: .utf8)) ?? "No logs available."
    }
    
    func openLogFile() {
        NSWorkspace.shared.open(logFileURL)
    }
}
