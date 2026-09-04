//
//  FocusObserver.swift
//  VisorPro
//
//  Created by MacBook on 04/09/2026.
//

import Foundation

class FocusObserver {
    private weak var manager: MediaKeyManager?
    private var timer: Timer?
    
    private var lastFocusActive: Bool = false
    private var lastModeName: String = "Focus"
    private var baselineSize: UInt64? = nil
    
    private var isInitialLoad: Bool = true
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
    
    init(manager: MediaKeyManager) {
        self.manager = manager
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.isInitialLoad = false
        }
        
        loadModeConfigurations()
        startObserving()
    }
    
    private func loadModeConfigurations() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let firstData = dataArray.first,
              let configs = firstData["modeConfigurations"] as? [String: Any] else {
            return
        }
        
        for (identifier, configData) in configs {
            if let configDict = configData as? [String: Any],
               let mode = configDict["mode"] as? [String: Any],
               let name = mode["name"] as? String {
                let colorName = mode["tintColorName"] as? String ?? "systemIndigoColor"
                let symbol = mode["symbolImageName"] as? String ?? "moon.fill"
                modeConfigsCache[identifier] = ModeConfig(name: name, colorName: colorName, symbol: symbol)
            }
        }
    }
    
    private var lastFocusColorName: String = "systemIndigoColor"
    private var lastFocusSymbol: String = "moon.fill"
    private var lastFocusDetails: MediaKeyManager.ActiveFocusDetails?
    
    func startObserving() {
        self.baselineSize = getAssertionsSize()
        
        // Initial state check
        let (isActive, modeName, colorName, symbol, details) = getDetailedFocusStatus()
        self.lastFocusActive = isActive
        self.lastModeName = modeName
        self.lastFocusColorName = colorName
        self.lastFocusSymbol = symbol
        self.lastFocusDetails = details
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.manager?.isFocusModeActive = isActive
            self.manager?.focusModeName = modeName
            self.manager?.focusColorName = colorName
            self.manager?.focusSymbol = symbol
            if isActive {
                self.manager?.activeFocusDetails = details
            }
            
            self.timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.pollFocusStatus()
            }
        }
    }
    
    private func pollFocusStatus() {
        let isDetailedMode = UserDefaults.standard.bool(forKey: "focusDetailMode")
        
        // Try reading exact JSON status first (requires Full Disk Access AND detailed mode enabled)
        if isDetailedMode && canReadAssertionsFile() {
            let (isActive, modeName, colorName, symbol, details) = getDetailedFocusStatus()
            
            // If the state is exactly the same, but the details changed (e.g. user added an end time)
            if isActive == lastFocusActive && modeName == lastModeName {
                if details != lastFocusDetails {
                    lastFocusDetails = details
                    DispatchQueue.main.async { [weak self] in
                        self?.manager?.activeFocusDetails = details
                    }
                }
            } else {
                let finalName = isActive ? modeName : self.lastModeName
                let finalColor = isActive ? colorName : self.lastFocusColorName
                let finalSymbol = isActive ? symbol : self.lastFocusSymbol
                triggerChangeIfNeeded(active: isActive, name: finalName, colorName: finalColor, symbol: finalSymbol, details: details)
            }
            return
        }
        
        // Fallback to size logic
        guard let currentSize = getAssertionsSize() else { return }
        var inferredActive = false
        
        if let baseline = baselineSize {
            if currentSize < baseline {
                baselineSize = currentSize // New baseline
                inferredActive = false
            } else if currentSize > baseline {
                inferredActive = true
            } else {
                inferredActive = false
            }
        } else {
            baselineSize = currentSize
        }
        
        let fallbackName = inferredActive ? "Focus" : self.lastModeName
        triggerChangeIfNeeded(active: inferredActive, name: fallbackName)
    }
    
    private func triggerChangeIfNeeded(active: Bool, name: String, colorName: String = "systemIndigoColor", symbol: String = "moon.fill", details: MediaKeyManager.ActiveFocusDetails? = nil) {
        if active != lastFocusActive || (active && name != lastModeName) {
            let isSwitched = (lastFocusActive == true && active == true && name != lastModeName)
            
            if !isInitialLoad {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.manager?.triggerFocusIndicator(isActive: active, modeName: name, colorName: colorName, symbol: symbol, isSwitched: isSwitched, details: details)
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.manager?.isFocusModeActive = active
                    self.manager?.focusModeName = name
                    self.manager?.focusColorName = colorName
                    self.manager?.focusSymbol = symbol
                    if active {
                        self.manager?.activeFocusDetails = details
                    }
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
    
    /// Parses Assertions.json to find if there is an active assertion, and returns its localized name.
    private func getDetailedFocusStatus() -> (isActive: Bool, modeName: String, colorName: String, symbol: String, details: MediaKeyManager.ActiveFocusDetails?) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: assertionsPath)),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let firstData = dataArray.first else {
            return (false, "Focus", "systemIndigoColor", "moon.fill", nil)
        }
        
        // If storeAssertionRecords is present and not empty, a Focus mode is active
        if let assertions = firstData["storeAssertionRecords"] as? [[String: Any]],
           let activeAssertion = assertions.first,
           let details = activeAssertion["assertionDetails"] as? [String: Any],
           let modeIdentifier = details["assertionDetailsModeIdentifier"] as? String {
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
                    else if client.contains("sleeping") { focusDetails.source = "Sleep Trigger" }
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
            return (true, "Focus", "systemIndigoColor", "moon.fill", focusDetails)
        }
        
        return (false, "Focus", "systemIndigoColor", "moon.fill", nil)
    }
    
    deinit {
        timer?.invalidate()
    }
}
