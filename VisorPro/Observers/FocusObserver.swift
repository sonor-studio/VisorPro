//
//  FocusObserver.swift
//  VisorPro
//
//  Created by MacBook on 04/09/2026.
//

import Foundation
import AppKit

class FocusObserver {
    private weak var manager: MediaKeyManager?
    private var timer: Timer?
    private let pollQueue = DispatchQueue(label: "com.visorpro.focus-poll", qos: .userInitiated)
    
    private var lastFocusActive: Bool = false
    private var lastModeName: String = "Focus"
    private var lastFocusColorName: String = "systemIndigoColor"
    private var lastFocusSymbol: String = "moon.fill"
    private var lastFocusDetails: MediaKeyManager.ActiveFocusDetails?
    
    private var lastSeenSize: UInt64? = nil
    private var baselineOffSize: UInt64? = nil
    private var baselineOnSize: UInt64? = nil
    
    private var folderWatcherSource: DispatchSourceFileSystemObject?
    private var folderWatcherFd: Int32 = -1
    
    private var isInitialLoad: Bool = true
    private var isSleeping: Bool = false
    private var isWakeGracePeriod: Bool = false
    
    private let dbPath = NSString(string: "~/Library/DoNotDisturb/DB").expandingTildeInPath
    private var assertionsPath: String { return dbPath + "/Assertions.json" }
    private var configPath: String { return dbPath + "/ModeConfigurations.json" }
    
    struct ModeConfig {
        let name: String
        let colorName: String
        let symbol: String
    }
    
    // Cache for mode configs (Identifier -> ModeConfig)
    private var modeConfigsCache: [String: ModeConfig] = [:]
    private var modeConfigsByName: [String: ModeConfig] = [:]
    
    init(manager: MediaKeyManager) {
        self.manager = manager
        
        let wsCenter = NSWorkspace.shared.notificationCenter
        wsCenter.addObserver(self, selector: #selector(systemWillSleep), name: NSWorkspace.willSleepNotification, object: nil)
        wsCenter.addObserver(self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.isInitialLoad = false
        }
        
        loadModeConfigurations()
        startObserving()
    }
    
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        timer?.invalidate()
        timer = nil
        closeFolderWatcher()
    }
    
    @objc private func systemWillSleep() {
        pollQueue.async { [weak self] in
            guard let self = self else { return }
            self.isSleeping = true
            DispatchQueue.main.async { [weak self] in
                self?.timer?.invalidate()
                self?.timer = nil
                self?.manager?.cancelFocusReminderTimerForSleep()
            }
            self.closeFolderWatcher()
        }
    }
    
    @objc private func systemDidWake() {
        pollQueue.async { [weak self] in
            guard let self = self else { return }
            self.isSleeping = false
            self.isWakeGracePeriod = true
            
            // Re-sync state silently after waking to absorb any iCloud changes made on other devices
            if self.canReadAssertionsFile() {
                let (isActive, modeName, colorName, symbol, details) = self.getDetailedFocusStatus()
                let isDetailed = UserDefaults.standard.bool(forKey: "focusDetailMode")
                let finalName = isDetailed ? modeName : (isActive ? "Focus" : self.lastModeName)
                let finalColor = isDetailed ? colorName : "systemIndigoColor"
                let finalSymbol = isDetailed ? symbol : (isActive ? "moon.fill" : "moon.zzz")
                
                self.lastFocusActive = isActive
                self.lastModeName = finalName
                self.lastFocusColorName = finalColor
                self.lastFocusSymbol = finalSymbol
                self.lastFocusDetails = details
                
                DispatchQueue.main.async { [weak self] in
                    self?.manager?.silentlyUpdateFocusState(isActive: isActive, modeName: finalName, colorName: finalColor, symbol: finalSymbol, details: details)
                }
            } else if let currentSize = self.getAssertionsSize() {
                // Re-baseline file size after wake so iCloud sync delta isn't mistaken for a manual toggle
                self.lastSeenSize = currentSize
                if !self.lastFocusActive {
                    self.baselineOffSize = currentSize
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.setupFolderWatcher()
                self.timer?.invalidate()
                self.timer = Timer.scheduledTimerInCommonModes(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                    self?.pollQueue.async {
                        self?.pollFocusStatus()
                    }
                }
                
                // Allow 6 seconds grace period before accepting live user changes or scheduling reminders
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) { [weak self] in
                    self?.isWakeGracePeriod = false
                    self?.manager?.scheduleFocusReminderAfterWake()
                }
            }
        }
    }
    
    private func loadModeConfigurations() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let firstData = dataArray.first,
              let configs = firstData["modeConfigurations"] as? [String: Any] else {
            return
        }
        
        var byId: [String: ModeConfig] = [:]
        var byName: [String: ModeConfig] = [:]
        
        for (identifier, configData) in configs {
            if let configDict = configData as? [String: Any],
               let mode = configDict["mode"] as? [String: Any],
               let name = mode["name"] as? String {
                let colorName = mode["tintColorName"] as? String ?? "systemIndigoColor"
                let symbol = mode["symbolImageName"] as? String ?? "moon.fill"
                let config = ModeConfig(name: name, colorName: colorName, symbol: symbol)
                byId[identifier] = config
                byName[name.lowercased()] = config
            }
        }
        
        self.modeConfigsCache = byId
        self.modeConfigsByName = byName
    }
    
    func getColorName(for modeName: String) -> String {
        return modeConfigsByName[modeName.lowercased()]?.colorName ?? "systemIndigoColor"
    }
    
    func getSymbol(for modeName: String) -> String {
        return modeConfigsByName[modeName.lowercased()]?.symbol ?? "moon.fill"
    }
    
    func syncStateFromNativeBanner(isActive: Bool, modeName: String, colorName: String = "systemIndigoColor", symbol: String = "moon.fill") {
        pollQueue.async { [weak self] in
            guard let self = self else { return }
            self.lastFocusActive = isActive
            self.lastModeName = modeName
            self.lastFocusColorName = colorName
            self.lastFocusSymbol = symbol
            if let currentSize = self.getAssertionsSize() {
                self.lastSeenSize = currentSize
                if !isActive {
                    self.baselineOffSize = currentSize
                } else {
                    self.baselineOnSize = currentSize
                }
            }
        }
    }
    
    func startObserving() {
        pollQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.lastSeenSize = self.getAssertionsSize()
            
            // Initial state check
            let (isActive, modeName, colorName, symbol, details) = self.getDetailedFocusStatus()
            let isDetailed = UserDefaults.standard.bool(forKey: "focusDetailMode")
            let finalName = isDetailed ? modeName : (isActive ? "Focus" : "Focus")
            let finalColor = isDetailed ? colorName : "systemIndigoColor"
            let finalSymbol = isDetailed ? symbol : (isActive ? "moon.fill" : "moon.zzz")
            
            self.lastFocusActive = isActive
            self.lastModeName = finalName
            self.lastFocusColorName = finalColor
            self.lastFocusSymbol = finalSymbol
            self.lastFocusDetails = details
            
            if !isActive, let initialSize = self.lastSeenSize {
                self.baselineOffSize = initialSize
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.manager?.silentlyUpdateFocusState(isActive: isActive, modeName: finalName, colorName: finalColor, symbol: finalSymbol, details: details)
                
                self.setupFolderWatcher()
                
                self.timer = Timer.scheduledTimerInCommonModes(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                    self?.pollQueue.async {
                        self?.pollFocusStatus()
                    }
                }
            }
        }
    }
    
    private func setupFolderWatcher() {
        closeFolderWatcher()
        let folderUrl = URL(fileURLWithPath: dbPath)
        let fd = open(folderUrl.path, O_EVTONLY)
        guard fd != -1 else { return }
        
        self.folderWatcherFd = fd
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write], queue: pollQueue)
        source.setEventHandler { [weak self] in
            self?.pollFocusStatus()
        }
        source.setCancelHandler { [weak self] in
            if let fd = self?.folderWatcherFd, fd != -1 {
                close(fd)
                self?.folderWatcherFd = -1
            }
        }
        source.resume()
        self.folderWatcherSource = source
    }
    
    private func closeFolderWatcher() {
        folderWatcherSource?.cancel()
        folderWatcherSource = nil
        if folderWatcherFd != -1 {
            close(folderWatcherFd)
            folderWatcherFd = -1
        }
    }
    
    private var lastDetailedMode: Bool? = nil
    
    private func pollFocusStatus() {
        guard !isSleeping else { return }
        
        let isDetailedMode = UserDefaults.standard.bool(forKey: "focusDetailMode") && PermissionHelper.hasFullDiskAccess()
        let silentUpdate = (lastDetailedMode != nil && lastDetailedMode != isDetailedMode) || isWakeGracePeriod || isInitialLoad
        self.lastDetailedMode = isDetailedMode
        
        // 1. Primary: If Assertions.json is readable (Full Disk Access present), always use exact JSON database state
        if canReadAssertionsFile() {
            let (isActive, modeName, colorName, symbol, details) = getDetailedFocusStatus()
            let finalName = isDetailedMode ? modeName : (isActive ? "Focus" : self.lastModeName)
            let finalColor = isDetailedMode ? colorName : "systemIndigoColor"
            let finalSymbol = isDetailedMode ? symbol : (isActive ? "moon.fill" : "moon.zzz")
            
            if isActive == lastFocusActive && finalName == lastModeName {
                if details != lastFocusDetails {
                    lastFocusDetails = details
                    DispatchQueue.main.async { [weak self] in
                        self?.manager?.activeFocusDetails = details
                    }
                }
            } else {
                triggerChangeIfNeeded(active: isActive, name: finalName, colorName: finalColor, symbol: finalSymbol, details: details, silentUpdate: silentUpdate)
            }
            
            if let currentSize = getAssertionsSize() {
                self.lastSeenSize = currentSize
                if !isActive {
                    self.baselineOffSize = currentSize
                } else {
                    self.baselineOnSize = currentSize
                }
            }
            return
        }
        
        // 2. Fallback: Size-based inference when Full Disk Access is not granted
        guard let currentSize = getAssertionsSize() else {
            // File might be in the middle of being atomically replaced. Retry in 100ms.
            pollQueue.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self, !self.isSleeping else { return }
                if let newSize = self.getAssertionsSize() {
                    self.lastSeenSize = newSize
                    self.pollFocusStatus()
                }
            }
            return
        }
        
        if isInitialLoad || isWakeGracePeriod {
            self.lastSeenSize = currentSize
            if !lastFocusActive {
                self.baselineOffSize = currentSize
            }
            return
        }
        
        let lastSize = self.lastSeenSize ?? currentSize
        var inferredActive = self.lastFocusActive
        
        if !self.lastFocusActive {
            // Currently OFF
            if let base = self.baselineOffSize {
                if currentSize > base + 85 {
                    inferredActive = true
                    self.baselineOnSize = currentSize
                } else {
                    // Gradual drift while OFF - adjust baseline down
                    self.baselineOffSize = min(base, currentSize)
                }
            } else if currentSize > lastSize + 85 {
                inferredActive = true
                self.baselineOnSize = currentSize
            }
        } else {
            // Currently ON
            if currentSize + 85 < lastSize {
                inferredActive = false
                self.baselineOffSize = currentSize
            } else if let base = self.baselineOffSize, currentSize <= base + 45 {
                // Absolute size returned near the recorded OFF baseline
                inferredActive = false
                self.baselineOffSize = currentSize
            }
        }
        
        self.lastSeenSize = currentSize
        let fallbackName = inferredActive ? "Focus" : self.lastModeName
        triggerChangeIfNeeded(active: inferredActive, name: fallbackName, silentUpdate: silentUpdate)
    }
    
    private func triggerChangeIfNeeded(active: Bool, name: String, colorName: String = "systemIndigoColor", symbol: String = "moon.fill", details: MediaKeyManager.ActiveFocusDetails? = nil, silentUpdate: Bool = false) {
        if active != lastFocusActive || (active && name != lastModeName) {
            let isSwitched = (lastFocusActive == true && active == true && name != lastModeName)
            
            if !isInitialLoad && !isWakeGracePeriod && !silentUpdate {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.manager?.triggerFocusIndicator(isActive: active, modeName: name, colorName: colorName, symbol: symbol, isSwitched: isSwitched, details: details)
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.manager?.silentlyUpdateFocusState(isActive: active, modeName: name, colorName: colorName, symbol: symbol, details: details)
                }
            }
            
            lastFocusActive = active
            lastModeName = name
            lastFocusColorName = colorName
            lastFocusSymbol = symbol
            lastFocusDetails = details
        }
    }
    
    private func getAssertionsSize() -> UInt64? {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: assertionsPath) else { return nil }
        return attrs[.size] as? UInt64
    }
    
    private func canReadAssertionsFile() -> Bool {
        return FileManager.default.isReadableFile(atPath: assertionsPath)
    }
    
    /// Parses Assertions.json to find if there is an active assertion, filtering out internal sleep assertions and expired records.
    private func getDetailedFocusStatus() -> (isActive: Bool, modeName: String, colorName: String, symbol: String, details: MediaKeyManager.ActiveFocusDetails?) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: assertionsPath)),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let firstData = dataArray.first else {
            return (false, "Focus", "systemIndigoColor", "moon.fill", nil)
        }
        
        if let assertions = firstData["storeAssertionRecords"] as? [[String: Any]], !assertions.isEmpty {
            for activeAssertion in assertions {
                guard let details = activeAssertion["assertionDetails"] as? [String: Any],
                      let modeIdentifier = details["assertionDetailsModeIdentifier"] as? String else {
                    continue
                }
                
                // Do not count internal system sleep assertions
                if let source = activeAssertion["assertionSource"] as? [String: Any],
                   let client = source["assertionClientIdentifier"] as? String,
                   client.contains("sleeping") {
                    continue
                }
                
                // Check if assertion has an end date that has already passed
                if let endTimestamp = details["assertionDetailsUserVisibleEndDate"] as? Double {
                    let endDate = Date(timeIntervalSinceReferenceDate: endTimestamp)
                    if endDate < Date() {
                        continue
                    }
                } else if let lifetime = details["assertionDetailsLifetime"] as? [String: Any],
                          let endTimestamp = lifetime["assertionDetailsDateIntervalLifetimeEndDateTimestamp"] as? Double {
                    let endDate = Date(timeIntervalSinceReferenceDate: endTimestamp)
                    if endDate < Date() {
                        continue
                    }
                }
                
                var focusDetails = MediaKeyManager.ActiveFocusDetails()
                
                if let startTimestamp = activeAssertion["assertionStartDateTimestamp"] as? Double {
                    focusDetails.startDate = Date(timeIntervalSinceReferenceDate: startTimestamp)
                }
                if let endTimestamp = details["assertionDetailsUserVisibleEndDate"] as? Double {
                    focusDetails.endDate = Date(timeIntervalSinceReferenceDate: endTimestamp)
                } else if let lifetime = details["assertionDetailsLifetime"] as? [String: Any] {
                    if let endTimestamp = lifetime["assertionDetailsDateIntervalLifetimeEndDateTimestamp"] as? Double {
                        focusDetails.endDate = Date(timeIntervalSinceReferenceDate: endTimestamp)
                    } else if let lifetimeType = lifetime["assertionDetailsLifetimeType"] as? String, lifetimeType == "current-location" {
                        focusDetails.untilLocationLeft = true
                    }
                }
                if let source = activeAssertion["assertionSource"] as? [String: Any] {
                    if let client = source["assertionClientIdentifier"] as? String {
                        if client.contains("controlcenter") { focusDetails.source = "Control Center" }
                        else if client.contains("schedule") { focusDetails.source = "Schedule" }
                        else if client.contains("workout") { focusDetails.source = "Workout Trigger" }
                        else if client.contains("activity-manager") { focusDetails.source = "System Activity" }
                        else if client.contains("intents") { focusDetails.source = "Shortcuts App" }
                        else { focusDetails.source = client }
                    }
                    if source["assertionSourceDeviceIdentifier"] as? String != nil {
                        focusDetails.device = "Other Device"
                    } else {
                        focusDetails.device = "This Mac"
                    }
                }
                
                if let config = modeConfigsCache[modeIdentifier] {
                    return (true, config.name, config.colorName, config.symbol, focusDetails)
                }
                
                // If not cached, reload cache once to see if user recently added this mode
                loadModeConfigurations()
                if let config = modeConfigsCache[modeIdentifier] {
                    return (true, config.name, config.colorName, config.symbol, focusDetails)
                }
                
                return (true, "Focus", "systemIndigoColor", "moon.fill", focusDetails)
            }
        }
        
        return (false, "Focus", "systemIndigoColor", "moon.fill", nil)
    }
}
