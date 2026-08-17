import Foundation
import Cocoa
import CoreGraphics

struct DisplayState: Equatable {
    let id: CGDirectDisplayID
    let name: String
    let isMirrored: Bool
    let resolution: String?
    let refreshRate: String?
    
    init(id: CGDirectDisplayID, name: String, isMirrored: Bool, resolution: String? = nil, refreshRate: String? = nil) {
        self.id = id
        self.name = name
        self.isMirrored = isMirrored
        self.resolution = resolution
        self.refreshRate = refreshRate
    }
}

class DisplayObserver {
    private weak var manager: MediaKeyManager?
    private var lastState: [String: DisplayState] = [:]
    private var debounceTimer: Timer?

    init(manager: MediaKeyManager) {
        self.manager = manager
        self.lastState = getCurrentState()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func getCurrentState() -> [String: DisplayState] {
        var state: [String: DisplayState] = [:]
        
        let maxDisplays: UInt32 = 16
        var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var displayCount: UInt32 = 0
        
        if CGGetOnlineDisplayList(maxDisplays, &onlineDisplays, &displayCount) == .success {
            var anyMirrored = false
            for i in 0..<Int(displayCount) {
                if CGDisplayMirrorsDisplay(onlineDisplays[i]) != kCGNullDirectDisplay {
                    anyMirrored = true
                    break
                }
            }
            
            for i in 0..<Int(displayCount) {
                let id = onlineDisplays[i]
                if CGDisplayIsBuiltin(id) == 0 {
                    var name = "External Display"
                    if let screen = NSScreen.screens.first(where: { $0.displayID == id }) {
                        name = screen.localizedName
                    } else if let old = lastState.values.first(where: { $0.id == id }) {
                        name = old.name
                    } else if lastState.count == 1, let old = lastState.values.first {
                        name = old.name
                    }
                    
                    let width = CGDisplayPixelsWide(id)
                    let height = CGDisplayPixelsHigh(id)
                    let resolution = "\(width) × \(height)"
                    
                    var hz = 60
                    if let mode = CGDisplayCopyDisplayMode(id) {
                        hz = Int(mode.refreshRate)
                        if hz == 0 { hz = 60 }
                    }
                    let refreshRate = "\(hz) Hz"
                    
                    state[name] = DisplayState(id: id, name: name, isMirrored: anyMirrored, resolution: resolution, refreshRate: refreshRate)
                }
            }
        }
        
        return state
    }

    @objc private func handleScreenChange() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.processStateChange()
        }
    }
    
    private func processStateChange() {
        let currentState = getCurrentState()
        let oldState = lastState
        
        let newIDs = currentState.keys.filter { oldState[$0] == nil }
        let removedIDs = oldState.keys.filter { currentState[$0] == nil }
        let keptIDs = currentState.keys.filter { oldState[$0] != nil }
        
        if !newIDs.isEmpty || !removedIDs.isEmpty {
            manager?.lastDisplayConnectionTime = Date()
        }
        
        let isSuppressed = DisplayController.lastManualToggle != nil && Date().timeIntervalSince(DisplayController.lastManualToggle!) < 3.0
        
        for name in removedIDs {
            if let oldDisplay = oldState[name] {
                if !isSuppressed {
                    manager?.triggerDisplayIndicator(
                        id: name,
                        deviceName: oldDisplay.name,
                        type: "Disconnected",
                        typeIcon: "display",
                        isConnected: false,
                        details: ["isMirrored": String(oldDisplay.isMirrored)]
                    )
                }
            }
        }
        
        for name in newIDs {
            if let newDisplay = currentState[name] {
                if !isSuppressed {
                    triggerOverlay(for: newDisplay, isConnected: true, isModeChange: false)
                }
            }
        }
        
        for name in keptIDs {
            if let oldDisplay = oldState[name], let newDisplay = currentState[name] {
                if oldDisplay.isMirrored != newDisplay.isMirrored {
                    if !isSuppressed {
                        triggerOverlay(for: newDisplay, isConnected: true, isModeChange: true)
                    }
                }
            }
        }
        
        lastState = currentState
    }
    
    private func triggerOverlay(for state: DisplayState, isConnected: Bool, isModeChange: Bool) {
        let typeText = state.isMirrored ? "Mode: Mirrored" : "Mode: Extended"
        
        let finalDeviceName = isModeChange ? "Changed to \(state.isMirrored ? "Mirrored" : "Extended")" : state.name
        let finalTypeText = isModeChange ? state.name : typeText
        
        var details = ["isMirrored": String(state.isMirrored)]
        if let res = state.resolution { details["resolution"] = res }
        if let rr = state.refreshRate { details["refreshRate"] = rr }
        
        manager?.triggerDisplayIndicator(
            id: state.name,
            deviceName: finalDeviceName,
            type: finalTypeText,
            typeIcon: state.isMirrored ? "display.2" : "macwindow.badge.plus",
            isConnected: isConnected,
            isModeChange: isModeChange,
            details: details
        )
    }

    deinit {
        debounceTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        return deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as? CGDirectDisplayID
    }
}

class DisplayController {
    static var lastManualToggle: Date? = nil
    
    static func toggleMirrorMode() {
        lastManualToggle = Date()
        let maxDisplays: UInt32 = 16
        var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var displayCount: UInt32 = 0
        
        CGGetOnlineDisplayList(maxDisplays, &onlineDisplays, &displayCount)
        guard displayCount > 1 else { return }
        
        let mainDisplay = CGMainDisplayID()
        var externalDisplay: CGDirectDisplayID? = nil
        var builtinDisplay: CGDirectDisplayID? = nil
        var mirroringDisplay: CGDirectDisplayID? = nil
        
        for i in 0..<Int(displayCount) {
            let id = onlineDisplays[i]
            if CGDisplayIsBuiltin(id) != 0 {
                builtinDisplay = id
            } else {
                externalDisplay = id
            }
            if CGDisplayMirrorsDisplay(id) != kCGNullDirectDisplay {
                mirroringDisplay = id
            }
        }
        
        guard let external = externalDisplay else { return }
        
        var config: CGDisplayConfigRef? = nil
        CGBeginDisplayConfiguration(&config)
        
        if let mirroring = mirroringDisplay {
            CGConfigureDisplayMirrorOfDisplay(config, mirroring, kCGNullDirectDisplay)
        } else {
            let target = builtinDisplay ?? mainDisplay
            CGConfigureDisplayMirrorOfDisplay(config, external, target)
        }
        
        CGCompleteDisplayConfiguration(config, .forSession)
    }
}
