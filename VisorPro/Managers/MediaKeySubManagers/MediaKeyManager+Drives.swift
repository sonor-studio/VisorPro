import Foundation
import AppKit
import SwiftUI

extension MediaKeyManager {
    func hasOpticalMedia() -> Bool? {
        let task = Process()
        task.launchPath = "/usr/bin/drutil"
        task.arguments = ["status"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
            let lower = output.lowercased()
            if lower.contains("no media inserted") || lower.contains("no media") || lower.contains("empty") {
                return false
            }
            return true
        }
        return nil
    }

    func getDriveCapacity(for notification: DeviceNotification) -> (total: Int, available: Int)? {
        guard let target = getMountPoint(for: notification) else { return nil }
        
        let keys: [URLResourceKey] = [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]
        if let values = try? target.resourceValues(forKeys: Set(keys)),
           let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity {
            return (total, available)
        }
        return nil
    }

    func openDrive(for notification: DeviceNotification) {
        if let target = getMountPoint(for: notification) {
            if notification.type == "CD/DVD Drive" {
                let videoTs = target.appendingPathComponent("VIDEO_TS")
                if FileManager.default.fileExists(atPath: videoTs.path) {
                    let task = Process()
                    task.launchPath = "/usr/bin/open"
                    task.arguments = ["-a", "DVD Player"]
                    try? task.run()
                    return
                }
                
                if let files = try? FileManager.default.contentsOfDirectory(atPath: target.path), files.contains(where: { $0.lowercased().hasSuffix(".aiff") || $0.lowercased().hasSuffix(".cda") }) {
                    let task = Process()
                    task.launchPath = "/usr/bin/open"
                    task.arguments = ["-a", "Music"]
                    try? task.run()
                    return
                }
            }
            
            NSWorkspace.shared.open(target)
        }
    }

    func ejectDrive(for notification: DeviceNotification, completion: @escaping (Bool, String?) -> Void = { _,_ in }) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let target = self.getMountPoint(for: notification) else {
                DispatchQueue.main.async { completion(false, nil) }
                return
            }
            
            let deviceNode = self.getDeviceNode(for: target.path)
            let task = Process()
            task.launchPath = "/usr/sbin/diskutil"
            task.arguments = ["unmount", target.path]
            do {
                try task.run()
                task.waitUntilExit()
                DispatchQueue.main.async { completion(task.terminationStatus == 0, deviceNode) }
            } catch {
                DispatchQueue.main.async { completion(false, nil) }
            }
        }
    }

    func mountDrive(deviceNode: String, completion: @escaping (Bool) -> Void = { _ in }) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.launchPath = "/usr/sbin/diskutil"
            task.arguments = ["mount", deviceNode]
            do {
                try task.run()
                task.waitUntilExit()
                DispatchQueue.main.async { completion(task.terminationStatus == 0) }
            } catch {
                DispatchQueue.main.async { completion(false) }
            }
        }
    }

}
