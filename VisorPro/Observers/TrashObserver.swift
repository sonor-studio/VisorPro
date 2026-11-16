import Foundation
import Combine
import AppKit

class TrashObserver: ObservableObject {
    static let shared = TrashObserver()
    
    private var timer: Timer?
    private var hasTriggeredAlert = false
    private var lastAlertSizeGB: Double = 0.0
    private var isInitialCheck = true
    private var initialWarmupTicks = 0
    private let trashURL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first!
    private var previousTrashItems: Set<String>? = nil
    private var tickCount = 0
    private var isCalculatingSize = false
    private let checkQueue = DispatchQueue(label: "com.sonorstudio.VisorPro.TrashCheck")
    private var ignoredFiles: [String: Date] = [:]
    private var lastAlertedFileName: String = ""
    private var lastAlertedTime: Date = .distantPast
    
    private init() {
        startMonitoring()
    }
    
    func ignoreFile(name: String) {
        checkQueue.async {
            self.ignoredFiles[name] = Date()
        }
    }
    
    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimerInCommonModes(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
        tick() // Initial check
    }
    
    private func tick() {
        tickCount += 1
        checkQueue.async {
            self.checkForDeletedFiles()
        }
    }
    
    private func checkForDeletedFiles() {
        do {
            // Clean up expired ignored files older than 5 seconds
            let now = Date()
            self.ignoredFiles = self.ignoredFiles.filter { now.timeIntervalSince($0.value) < 5.0 }
            
            var currentItems = Set<String>()
            var fileURLMap: [String: URL] = [:]
            
            // Local trash (fast directory listing without property prefetching that blocks permissions)
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: self.trashURL.path) {
                for item in contents where !item.hasPrefix(".") {
                    currentItems.insert(item)
                    fileURLMap[item] = self.trashURL.appendingPathComponent(item)
                }
            }
            
            // iCloud trash (if exists in Mobile Documents)
            if let libURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first {
                let icloudTrash = libURL.appendingPathComponent("Mobile Documents/com~apple~CloudDocs/.Trash")
                if FileManager.default.fileExists(atPath: icloudTrash.path),
                   let icloudItems = try? FileManager.default.contentsOfDirectory(atPath: icloudTrash.path) {
                    for item in icloudItems where !item.hasPrefix(".") {
                        currentItems.insert(item)
                        if fileURLMap[item] == nil {
                            fileURLMap[item] = icloudTrash.appendingPathComponent(item)
                        }
                    }
                }
            }
            
            // Warm-up phase: establish baseline without firing any alerts for existing files
            if initialWarmupTicks < 3 {
                initialWarmupTicks += 1
                self.previousTrashItems = currentItems
                return
            }
            
            if let previous = self.previousTrashItems {
                if currentItems != previous {
                    let newItems = currentItems.subtracting(previous)
                    
                    // Ignore bulk appearances (e.g. permission grant, clearing large directory, external disk)
                    if newItems.count > 5 {
                        self.previousTrashItems = currentItems
                        return
                    }
                    
                    if let firstNewName = newItems.first, let firstNew = fileURLMap[firstNewName] {
                        let name = firstNewName
                        
                        // Check if file is currently ignored (e.g. during Put Back / restore)
                        if self.ignoredFiles[name] != nil {
                            self.previousTrashItems = currentItems
                            return
                        }
                        
                        // Debounce identical file alerts within 5 seconds
                        if name == self.lastAlertedFileName && now.timeIntervalSince(self.lastAlertedTime) < 5.0 {
                            self.previousTrashItems = currentItems
                            return
                        }
                        
                        let resourceValues = try? firstNew.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                        let isDir = resourceValues?.isDirectory ?? false
                        let fileSizeBytes = Double(resourceValues?.fileSize ?? 0)
                        let fileSizeMB = isDir ? -1.0 : (fileSizeBytes / 1_000_000.0)
                        
                        self.lastAlertedFileName = name
                        self.lastAlertedTime = now
                        let icon = NSWorkspace.shared.icon(forFile: firstNew.path)
                        
                        DispatchQueue.main.async {
                            MediaKeyManager.shared.lastDeletedFileName = name
                            MediaKeyManager.shared.lastDeletedFileSizeMB = fileSizeMB
                            MediaKeyManager.shared.lastDeletedFileIcon = icon
                            MediaKeyManager.shared.lastDeletedFileURL = firstNew
                            MediaKeyManager.shared.triggerFileDeletedOverlay()
                        }
                        
                        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.0) {
                            if !self.isCalculatingSize {
                                self.isCalculatingSize = true
                                self.updateTrashStats(didAddItems: true)
                                self.isCalculatingSize = false
                            }
                        }
                    } else {
                        // File was removed (emptied or restored)
                        if !self.isCalculatingSize {
                            self.isCalculatingSize = true
                            self.updateTrashStats(didAddItems: false)
                            self.isCalculatingSize = false
                        }
                    }
                }
            } else {
                if !self.isCalculatingSize {
                    self.isCalculatingSize = true
                    self.updateTrashStats(didAddItems: false)
                    self.isCalculatingSize = false
                }
            }
            self.previousTrashItems = currentItems
        }
    }
    
    private func updateTrashStats(didAddItems: Bool = false) {
        let (size, count, folders, largestMB) = self.calculateTrashSizeAndCount(at: self.trashURL)
        let sizeGB = Double(size) / 1_000_000_000.0
        
        DispatchQueue.main.async {
            MediaKeyManager.shared.trashSizeGB = sizeGB
            MediaKeyManager.shared.trashFileCount = count
            MediaKeyManager.shared.trashFolderCount = folders
            MediaKeyManager.shared.trashLargestItemMB = largestMB
            
            let threshold = MediaKeyManager.shared.trashSizeThresholdGB
            
            if sizeGB >= threshold && sizeGB > 0 {
                if !self.hasTriggeredAlert || (sizeGB - self.lastAlertSizeGB >= 0.5) {
                    self.hasTriggeredAlert = true
                    self.lastAlertSizeGB = sizeGB
                    
                    if !self.isInitialCheck {
                        if MediaKeyManager.shared.trashAutoEmpty {
                            self.emptyTrash(isAutoEmpty: true, freedSize: sizeGB)
                        } else {
                            MediaKeyManager.shared.trashAutoEmptied = false
                            MediaKeyManager.shared.triggerTrashOverlay()
                        }
                    }
                }
            } else if sizeGB < threshold {
                self.hasTriggeredAlert = false
                self.lastAlertSizeGB = 0.0
                
                // Hide only if it's currently showing "Trash is Full", don't hide the "Trash Emptied" overlay
                if !MediaKeyManager.shared.trashAutoEmptied {
                    MediaKeyManager.shared.forceHide(overlayId: "trash")
                }
            }
            
            self.isInitialCheck = false
        }
    }
    
    private func calculateTrashSizeAndCount(at url: URL) -> (UInt64, Int, Int, Double) {
        var totalSize: UInt64 = 0
        var fileCount = 0
        var folderCount = 0
        var largestItemBytes: UInt64 = 0
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsSubdirectoryDescendants]) else {
            return (0, 0, 0, 0.0)
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                
                if let isDirectory = resourceValues.isDirectory {
                    if isDirectory {
                        folderCount += 1
                    } else {
                        let fSize = UInt64(resourceValues.fileSize ?? 0)
                        totalSize += fSize
                        fileCount += 1
                        if fSize > largestItemBytes {
                            largestItemBytes = fSize
                        }
                    }
                }
            } catch {
                continue
            }
        }
        
        let largestMB = Double(largestItemBytes) / 1_000_000.0
        return (totalSize, fileCount, folderCount, largestMB)
    }
    
    func emptyTrash(isAutoEmpty: Bool = false, freedSize: Double = 0.0) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            
            // Empty local trash
            if let enumerator = fileManager.enumerator(at: self.trashURL, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants]) {
                for case let fileURL as URL in enumerator {
                    try? fileManager.removeItem(at: fileURL)
                }
            }
            
            // Empty iCloud trash
            if let icloudURL = fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent(".Trash"),
               let icloudEnumerator = fileManager.enumerator(at: icloudURL, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants]) {
                for case let fileURL as URL in icloudEnumerator {
                    try? fileManager.removeItem(at: fileURL)
                }
            }
            
            DispatchQueue.main.async {
                if isAutoEmpty {
                    MediaKeyManager.shared.trashFreedSizeGB = freedSize
                    MediaKeyManager.shared.trashAutoEmptied = true
                    MediaKeyManager.shared.triggerTrashOverlay(isManualTrigger: true)
                } else {
                    // Update stats immediately to reflect empty state
                    self.updateTrashStats()
                }
            }
        }
    }
}
