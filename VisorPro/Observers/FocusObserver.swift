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
    private var lastNativeBannerSyncTime: Date = Date.distantPast
    
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
                let finalName = isDetailed ? modeName : (isActive ? modeName : self.lastModeName)
                let finalColor = colorName
                let finalSymbol = symbol
                
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
        var byId: [String: ModeConfig] = [
            "com.apple.donotdisturb.mode.default": ModeConfig(name: "Do Not Disturb", colorName: "systemIndigoColor", symbol: "moon.fill"),
            "com.apple.donotdisturb.mode.sleep": ModeConfig(name: "Sleep", colorName: "systemMintColor", symbol: "bed.double.fill"),
            "com.apple.focus.mode.sleep": ModeConfig(name: "Sleep", colorName: "systemMintColor", symbol: "bed.double.fill"),
            "com.apple.donotdisturb.mode.work": ModeConfig(name: "Work", colorName: "systemTealColor", symbol: "briefcase.fill"),
            "com.apple.donotdisturb.mode.personal": ModeConfig(name: "Personal", colorName: "systemPurpleColor", symbol: "person.fill"),
            "com.apple.donotdisturb.mode.driving": ModeConfig(name: "Driving", colorName: "systemIndigoColor", symbol: "car.fill"),
            "com.apple.donotdisturb.mode.fitness": ModeConfig(name: "Fitness", colorName: "systemOrangeColor", symbol: "figure.run"),
            "com.apple.donotdisturb.mode.gaming": ModeConfig(name: "Gaming", colorName: "systemPurpleColor", symbol: "gamecontroller.fill"),
            "com.apple.donotdisturb.mode.reading": ModeConfig(name: "Reading", colorName: "systemYellowColor", symbol: "book.closed.fill"),
            "com.apple.focus.reduce-interruptions": ModeConfig(name: "Reduce Interruptions", colorName: "reduceInterruptionsColor", symbol: "apple.intelligence")
        ]
        var byName: [String: ModeConfig] = [
            "do not disturb": ModeConfig(name: "Do Not Disturb", colorName: "systemIndigoColor", symbol: "moon.fill"),
            "nie przeszkadzać": ModeConfig(name: "Do Not Disturb", colorName: "systemIndigoColor", symbol: "moon.fill"),
            "sleep": ModeConfig(name: "Sleep", colorName: "systemMintColor", symbol: "bed.double.fill"),
            "sen": ModeConfig(name: "Sleep", colorName: "systemMintColor", symbol: "bed.double.fill"),
            "work": ModeConfig(name: "Work", colorName: "systemTealColor", symbol: "briefcase.fill"),
            "praca": ModeConfig(name: "Work", colorName: "systemTealColor", symbol: "briefcase.fill"),
            "personal": ModeConfig(name: "Personal", colorName: "systemPurpleColor", symbol: "person.fill"),
            "osobisty": ModeConfig(name: "Personal", colorName: "systemPurpleColor", symbol: "person.fill"),
            "fitness": ModeConfig(name: "Fitness", colorName: "systemOrangeColor", symbol: "figure.run"),
            "trening": ModeConfig(name: "Fitness", colorName: "systemOrangeColor", symbol: "figure.run"),
            "reduce interruptions": ModeConfig(name: "Reduce Interruptions", colorName: "reduceInterruptionsColor", symbol: "apple.intelligence")
        ]
        
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let firstData = dataArray.first,
              let configs = firstData["modeConfigurations"] as? [String: Any] else {
            self.modeConfigsCache = byId
            self.modeConfigsByName = byName
            return
        }
        
        for (identifier, configData) in configs {
            if let configDict = configData as? [String: Any],
               let mode = configDict["mode"] as? [String: Any],
               let rawName = mode["name"] as? String {
                let lowerRaw = rawName.lowercased()
                let lowerId = identifier.lowercased()
                let isReduceInterruptions = lowerRaw == "_gm" || lowerRaw.contains("reduce") || lowerRaw.contains("interrupt") || lowerRaw.contains("redukuj") || lowerId.contains("reduce") || lowerId.contains("interrupt") || lowerId.contains("_gm")
                
                let name: String
                let symbol: String
                let colorName: String
                
                if isReduceInterruptions {
                    name = "Reduce Interruptions"
                    symbol = "apple.intelligence"
                    colorName = "reduceInterruptionsColor"
                } else if lowerRaw == "itunes u" || lowerRaw == "itunes" {
                    name = "Szkoła"
                    symbol = "graduationcap.fill"
                    colorName = "systemYellowColor"
                } else {
                    name = rawName
                    let rawSymbol = mode["symbolImageName"] as? String ?? ""
                    symbol = (rawSymbol.isEmpty || rawSymbol == "_gm" || rawSymbol.contains("gm")) ? (rawSymbol == "_gm" ? "apple.intelligence" : "moon.fill") : rawSymbol
                    colorName = mode["tintColorName"] as? String ?? "systemIndigoColor"
                }
                
                let config = ModeConfig(name: name, colorName: colorName, symbol: symbol)
                byId[identifier] = config
                byName[name.lowercased()] = config
                if isReduceInterruptions {
                    byId["com.apple.focus.reduce-interruptions"] = config
                    byName["_gm"] = config
                    byName["reduce interruptions"] = config
                }
            }
        }
        
        self.modeConfigsCache = byId
        self.modeConfigsByName = byName
    }
    
    func getColorName(for modeName: String) -> String {
        let lower = modeName.lowercased()
        if let configColor = modeConfigsByName[lower]?.colorName {
            return configColor
        }
        if lower.contains("reduce") || lower.contains("interrupt") || lower.contains("redukuj") || lower.contains("zakłócenia") || lower == "_gm" {
            return "reduceInterruptionsColor" // Apple Intelligence authentic neon magenta-purple (#CB30E0)
        } else if lower.contains("disturb") || lower.contains("nie przeszkadzać") || lower == "focus" {
            return "systemIndigoColor"
        } else if lower.contains("work") || lower.contains("praca") {
            return "systemTealColor"
        } else if lower.contains("sleep") || lower.contains("sen") || lower.contains("bedtime") {
            return "systemMintColor"
        } else if lower.contains("personal") || lower.contains("osobisty") {
            return "systemPurpleColor"
        } else if lower.contains("fitness") || lower.contains("trening") || lower.contains("running") {
            return "systemOrangeColor"
        } else if lower.contains("szkoła") || lower.contains("school") || lower.contains("study") || lower.contains("nauka") || lower.contains("itunes") {
            return "systemYellowColor"
        } else if lower.contains("reading") || lower.contains("czytanie") {
            return "systemYellowColor"
        } else if lower.contains("gaming") || lower.contains("gry") {
            return "systemPurpleColor"
        } else if lower.contains("driving") || lower.contains("kierowanie") || lower.contains("samochód") {
            return "systemIndigoColor"
        }
        return "systemIndigoColor"
    }
    
    func getSymbol(for modeName: String) -> String {
        let lower = modeName.lowercased()
        if let configSymbol = modeConfigsByName[lower]?.symbol {
            return configSymbol
        }
        if lower.contains("reduce") || lower.contains("interrupt") || lower.contains("redukuj") || lower.contains("zakłócenia") || lower == "_gm" {
            return "apple.intelligence"
        } else if lower.contains("disturb") || lower.contains("nie przeszkadzać") || lower == "focus" {
            return "moon.fill"
        } else if lower.contains("work") || lower.contains("praca") {
            return "briefcase.fill"
        } else if lower.contains("sleep") || lower.contains("sen") || lower.contains("bedtime") {
            return "bed.double.fill"
        } else if lower.contains("personal") || lower.contains("osobisty") {
            return "person.fill"
        } else if lower.contains("fitness") || lower.contains("trening") || lower.contains("running") {
            return "figure.run"
        } else if lower.contains("szkoła") || lower.contains("school") || lower.contains("study") || lower.contains("nauka") || lower.contains("itunes") {
            return "graduationcap.fill"
        } else if lower.contains("reading") || lower.contains("czytanie") {
            return "book.closed.fill"
        } else if lower.contains("gaming") || lower.contains("gry") {
            return "gamecontroller.fill"
        } else if lower.contains("driving") || lower.contains("kierowanie") || lower.contains("samochód") {
            return "car.fill"
        }
        return "moon.fill"
    }
    
    func syncStateFromNativeBanner(isActive: Bool, modeName: String, colorName: String = "systemIndigoColor", symbol: String = "moon.fill") {
        pollQueue.async { [weak self] in
            guard let self = self else { return }
            self.lastNativeBannerSyncTime = Date()
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
            let initialDefaultName = (modeName.isEmpty || modeName.lowercased() == "focus") ? "Do Not Disturb" : modeName
            let finalName = isDetailed ? initialDefaultName : (isActive ? initialDefaultName : "Do Not Disturb")
            let finalColor = colorName
            let finalSymbol = symbol
            
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
            let finalName: String
            let finalColor: String
            let finalSymbol: String
            
            if isActive {
                finalName = modeName
                finalColor = colorName
                finalSymbol = symbol
            } else {
                // When turning OFF, ALWAYS preserve the last active mode's name, color, and symbol!
                finalName = (self.lastModeName.isEmpty || self.lastModeName.lowercased() == "focus") ? modeName : self.lastModeName
                finalColor = self.lastFocusColorName
                finalSymbol = self.lastFocusSymbol
            }
            
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
        // When native banner tracking is active (NativeOverlayDismisser handles AX banners),
        // size heuristics on Assertions.json must NEVER synthesize a generic "Focus"/"moon.fill" trigger.
        // Doing so causes a double-pop or displays a moon icon before the native banner delivers the exact mode.
        // NativeOverlayDismisser is the authoritative source for user-initiated Focus toggles.
        guard let currentSize = getAssertionsSize() else {
            return
        }
        
        self.lastSeenSize = currentSize
        if !lastFocusActive {
            self.baselineOffSize = currentSize
        } else {
            self.baselineOnSize = currentSize
        }
        return
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
    
    /// Parses Assertions.json to find if there is an active assertion, filtering out expired records.
    private func getDetailedFocusStatus() -> (isActive: Bool, modeName: String, colorName: String, symbol: String, details: MediaKeyManager.ActiveFocusDetails?) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: assertionsPath)),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let firstData = dataArray.first else {
            let fallbackOffName = (self.lastModeName.isEmpty || self.lastModeName.lowercased() == "focus") ? "Do Not Disturb" : self.lastModeName
            return (false, fallbackOffName, self.lastFocusColorName, self.lastFocusSymbol, nil)
        }
        
        if let assertions = firstData["storeAssertionRecords"] as? [[String: Any]], !assertions.isEmpty {
            // Sort assertions by assertionStartDateTimestamp descending so that the latest activated Focus mode is evaluated first
            let sortedAssertions = assertions.sorted { a, b in
                let timeA = a["assertionStartDateTimestamp"] as? Double ?? 0
                let timeB = b["assertionStartDateTimestamp"] as? Double ?? 0
                return timeA > timeB
            }
            
            for activeAssertion in sortedAssertions {
                guard let details = activeAssertion["assertionDetails"] as? [String: Any],
                      let modeIdentifier = details["assertionDetailsModeIdentifier"] as? String else {
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
                        let clientLower = client.lowercased()
                        if clientLower.contains("controlcenter") { focusDetails.source = "Control Center" }
                        else if clientLower.contains("schedule") { focusDetails.source = "Schedule" }
                        else if clientLower.contains("sleeping") || clientLower.contains("sleep") || clientLower.contains("bedtime") { focusDetails.source = "Sleep Schedule" }
                        else if clientLower.contains("workout") || clientLower.contains("fitness") { focusDetails.source = "Workout Trigger" }
                        else if clientLower.contains("activity-manager") { focusDetails.source = "System Activity" }
                        else if clientLower.contains("intents") { focusDetails.source = "Shortcuts App" }
                        else { focusDetails.source = client }
                    }
                    if source["assertionSourceDeviceIdentifier"] as? String != nil {
                        focusDetails.device = "Other Device"
                    } else {
                        focusDetails.device = "This Mac"
                    }
                }
                
                let lowerId = modeIdentifier.lowercased()
                if lowerId.contains("reduce") || lowerId.contains("interrupt") || lowerId.contains("_gm") {
                    return (true, "Reduce Interruptions", "reduceInterruptionsColor", "apple.intelligence", focusDetails)
                } else if lowerId.contains("sleep") || lowerId.contains("bedtime") {
                    return (true, "Sleep", "systemMintColor", "bed.double.fill", focusDetails)
                } else if lowerId.contains("default") || lowerId.contains("disturb") {
                    return (true, "Do Not Disturb", "systemIndigoColor", "moon.fill", focusDetails)
                } else if lowerId.contains("work") {
                    return (true, "Work", "systemTealColor", "briefcase.fill", focusDetails)
                } else if lowerId.contains("personal") {
                    return (true, "Personal", "systemPurpleColor", "person.fill", focusDetails)
                } else if lowerId.contains("fitness") || lowerId.contains("running") {
                    return (true, "Fitness", "systemOrangeColor", "figure.run", focusDetails)
                } else if lowerId.contains("driving") {
                    return (true, "Driving", "systemIndigoColor", "car.fill", focusDetails)
                } else if lowerId.contains("reading") {
                    return (true, "Reading", "systemYellowColor", "book.closed.fill", focusDetails)
                } else if lowerId.contains("gaming") {
                    return (true, "Gaming", "systemPurpleColor", "gamecontroller.fill", focusDetails)
                }
                
                if let config = modeConfigsCache[modeIdentifier] {
                    let cName = (config.name.lowercased() == "_gm" || config.name.lowercased().contains("reduce") || config.name.lowercased().contains("interrupt")) ? "Reduce Interruptions" : config.name
                    let cSymbol = (config.symbol == "_gm" || cName == "Reduce Interruptions") ? "apple.intelligence" : config.symbol
                    return (true, cName, config.colorName, cSymbol, focusDetails)
                }
                
                // If not cached, reload cache once to see if user recently added this mode
                loadModeConfigurations()
                if let config = modeConfigsCache[modeIdentifier] {
                    let cName = (config.name.lowercased() == "_gm" || config.name.lowercased().contains("reduce") || config.name.lowercased().contains("interrupt")) ? "Reduce Interruptions" : config.name
                    let cSymbol = (config.symbol == "_gm" || cName == "Reduce Interruptions") ? "apple.intelligence" : config.symbol
                    return (true, cName, config.colorName, cSymbol, focusDetails)
                }
                
                let fallbackName = (self.lastModeName.isEmpty || self.lastModeName.lowercased() == "focus") ? "Do Not Disturb" : self.lastModeName
                let fallbackColor = self.getColorName(for: fallbackName)
                let fallbackSymbol = self.getSymbol(for: fallbackName)
                return (true, fallbackName, fallbackColor, fallbackSymbol, focusDetails)
            }
        }
        
        let fallbackOffName = (self.lastModeName.isEmpty || self.lastModeName.lowercased() == "focus") ? "Do Not Disturb" : self.lastModeName
        return (false, fallbackOffName, self.lastFocusColorName, self.lastFocusSymbol, nil)
    }
}
