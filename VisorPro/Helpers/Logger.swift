import Foundation

class Logger {
    static func log(_ message: String) {
        let fileURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/VisorProWiFiLog.txt")
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let time = formatter.string(from: Date())
        let text = "[\(time)] \(message)\n"
        
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            handle.seekToEndOfFile()
            if let data = text.data(using: .utf8) {
                handle.write(data)
            }
            handle.closeFile()
        } else {
            try? text.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
}
