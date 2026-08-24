import Foundation
import Combine
import Darwin
import AppKit

class RamObserver: ObservableObject {
    static let shared = RamObserver()
    
    @Published var totalRamGB: Double = 0.0
    @Published var usedRamGB: Double = 0.0
    @Published var ramUsagePercent: Double = 0.0
    @Published var topProcesses: [(name: String, ramGB: Double)] = []
    
    private var timer: Timer?
    private var hasTriggeredAlert = false
    private var tickCount = 0
    
    private init() {
        self.totalRamGB = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)
        startMonitoring()
    }
    
    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        tick()
    }
    
    private func tick() {
        let isVisible = MediaKeyManager.shared.showRamIndicator
        if isVisible || tickCount % 5 == 0 {
            updateRamUsage()
        }
        tickCount += 1
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateRamUsage() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let total = Double(ProcessInfo.processInfo.physicalMemory)
            let free = Double(stats.free_count) * Double(vm_page_size)
            let cached = Double(stats.external_page_count + stats.purgeable_count) * Double(vm_page_size)
            let used = total - free - cached
            let percent = (used / total) * 100.0
            
            print("[RamObserver] updateRamUsage. Used: \(used / (1024*1024*1024)) GB, Total: \(total / (1024*1024*1024)) GB, Percent: \(percent)%")
            
            DispatchQueue.main.async {
                self.usedRamGB = used / (1024 * 1024 * 1024)
                self.ramUsagePercent = percent
                
                // Sync with MediaKeyManager
                MediaKeyManager.shared.ramUsagePercent = percent
                MediaKeyManager.shared.usedRamGB = self.usedRamGB
                MediaKeyManager.shared.totalRamGB = self.totalRamGB
                
                if MediaKeyManager.shared.ramUsageHistory.isEmpty {
                    MediaKeyManager.shared.ramUsageHistory = Array(repeating: percent, count: 40)
                } else {
                    MediaKeyManager.shared.ramUsageHistory.append(percent)
                    if MediaKeyManager.shared.ramUsageHistory.count > 40 {
                        MediaKeyManager.shared.ramUsageHistory.removeFirst()
                    }
                }
                
                let threshold = MediaKeyManager.shared.highRamThreshold
                print("[RamObserver] Current threshold: \(threshold)%. Current percent: \(percent)%")
                
                // Allow triggering if rounded percent is at least threshold
                if percent >= threshold || abs(percent - threshold) < 0.5 {
                    if !self.hasTriggeredAlert {
                        print("[RamObserver] Triggering RAM overlay! percent: \(percent) >= threshold: \(threshold)")
                        self.hasTriggeredAlert = true
                        MediaKeyManager.shared.triggerRamOverlay()
                    } else {
                        print("[RamObserver] RAM still high, but alert already triggered.")
                    }
                } else if percent <= (threshold - 5.0) {
                    if self.hasTriggeredAlert {
                        print("[RamObserver] Resetting alert flag. percent: \(percent) <= \(threshold - 5.0)")
                        self.hasTriggeredAlert = false
                    }
                }
            }
            
            self.fetchTopProcesses()
        }
    }
    
    func resetAlertFlag() {
        DispatchQueue.main.async {
            self.hasTriggeredAlert = false
            print("[RamObserver] Alert flag manually reset")
        }
    }
    
    private func fetchTopProcesses() {
        DispatchQueue.global(qos: .background).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/ps")
            task.arguments = ["-c", "-ax", "-o", "pid,rss,comm"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            do {
                try task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let lines = output.components(separatedBy: .newlines).dropFirst()
                    var processes: [(name: String, ramGB: Double)] = []
                    
                    for line in lines {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.isEmpty { continue }
                        
                        let parts = trimmed.components(separatedBy: CharacterSet.whitespaces).filter { !$0.isEmpty }
                        guard parts.count >= 3 else { continue }
                        
                        if let pid = Int32(parts[0]), let rssKb = Double(parts[1]) {
                            var footprintBytes: Double = rssKb * 1024.0
                            
                            // Try to get true physical footprint natively!
                            var info = rusage_info_v2()
                            let result = withUnsafeMutablePointer(to: &info) { ptr in
                                ptr.withMemoryRebound(to: Optional<UnsafeMutableRawPointer>.self, capacity: 1) { rawPtr in
                                    proc_pid_rusage(pid, RUSAGE_INFO_V2, rawPtr)
                                }
                            }
                            
                            if result == 0 {
                                footprintBytes = Double(info.ri_phys_footprint)
                            }
                            
                            let gb = footprintBytes / (1024.0 * 1024.0 * 1024.0)
                            if gb > 0.05 { // Skip tiny processes
                                var name = parts[2...].joined(separator: " ")
                                
                                // Try to get a friendly name
                                if let app = NSRunningApplication(processIdentifier: pid), let localized = app.localizedName, !localized.isEmpty {
                                    name = localized
                                } else {
                                    // Fallback text replacements for common technical names
                                    if name.hasPrefix("com.apple.WebKit.") {
                                        name = name.replacingOccurrences(of: "com.apple.WebKit.", with: "Safari ")
                                    } else if name.hasPrefix("com.apple.") {
                                        name = name.replacingOccurrences(of: "com.apple.", with: "Apple ")
                                    }
                                }
                                
                                processes.append((name: name, ramGB: gb))
                            }
                        }
                    }
                    
                    processes.sort { $0.ramGB > $1.ramGB }
                    let top = Array(processes.prefix(5))
                    
                    DispatchQueue.main.async {
                        self.topProcesses = top
                        MediaKeyManager.shared.ramTopProcesses = top
                    }
                }
            } catch {
                print("[RamObserver] Failed to run ps: \(error)")
            }
        }
    }
}
