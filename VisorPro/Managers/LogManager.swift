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
        
        // Keep logs across sessions but trim if file exceeds 1MB to avoid infinite growth
        if fileManager.fileExists(atPath: logFileURL.path) {
            if let attributes = try? fileManager.attributesOfItem(atPath: logFileURL.path),
               let fileSize = attributes[.size] as? UInt64,
               fileSize > 1024 * 1024 { // 1 MB
                
                if let content = try? String(contentsOf: logFileURL, encoding: .utf8) {
                    let lines = content.split(separator: "\n")
                    let recentLines = lines.suffix(1000).joined(separator: "\n") + "\n"
                    try? recentLines.write(to: logFileURL, atomically: true, encoding: .utf8)
                } else {
                    try? fileManager.removeItem(at: logFileURL)
                    fileManager.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
                }
            }
            
            // Insert a visual separator for the new session
            if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                let separator = "\n========================================\nNEW SESSION STARTED\n========================================\n"
                if let data = separator.data(using: .utf8) {
                    if #available(macOS 10.15.4, *) {
                        _ = try? fileHandle.seekToEnd()
                        _ = try? fileHandle.write(contentsOf: data)
                    } else {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                    }
                }
                fileHandle.closeFile()
            }
        } else {
            // Create initial empty file
            fileManager.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
        }
        
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
        // Logs removed per request
        // print(logMessage, terminator: "")
    }
    
    func getLogs() -> String {
        return (try? String(contentsOf: logFileURL, encoding: .utf8)) ?? "No logs available."
    }
    
    func openLogFile() {
        NSWorkspace.shared.open(logFileURL)
    }
}
