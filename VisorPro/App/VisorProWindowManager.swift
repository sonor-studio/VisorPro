import Foundation
import AppKit
import SwiftUI
import Combine
import TelemetryClient

@MainActor
class VisorProWindowManager: ObservableObject {
    static let shared = VisorProWindowManager()
    
    private var windows: [String: NSPanel] = [:]
    private var targetOrigins: [String: NSPoint] = [:]
    private var logicalTargetOrigins: [String: NSPoint] = [:]
    private(set) var cachedScreens: [NSScreen] = NSScreen.screens
    private var shownPanels: Set<String> = []
    private var exitingPanels: Set<String> = []
    private var cancellables = Set<AnyCancellable>()
    private var overlayTimestamps: [String: Date] = [:]
    private var animatingEntryPanels: Set<String> = []
    private var reportedTelemetryTimestamps: [String: Date] = [:]
    
    private func assignSlots(overlays: [ActiveOverlay], limit: Int) -> [String: Int] {
        var slotMap: [String: Int] = [:]
        var filledSlots = Set<Int>()
        
        let lefts = overlays.filter { $0.position.hasSuffix("_left") }
        let rights = overlays.filter { $0.position.hasSuffix("_right") }
        let centers = overlays.filter { !$0.position.hasSuffix("_left") && !$0.position.hasSuffix("_right") }
        
        for overlay in lefts {
            for i in 0..<limit {
                if !filledSlots.contains(i) {
                    slotMap[overlay.id] = i
                    filledSlots.insert(i)
                    break
                }
            }
        }
        
        for overlay in rights {
            for i in (0..<limit).reversed() {
                if !filledSlots.contains(i) {
                    slotMap[overlay.id] = i
                    filledSlots.insert(i)
                    break
                }
            }
        }
        
        let middle = limit / 2
        for overlay in centers {
            var bestSlot = -1
            var minDistance = Int.max
            for i in 0..<limit {
                if !filledSlots.contains(i) {
                    let dist = abs(i - middle)
                    if dist < minDistance {
                        minDistance = dist
                        bestSlot = i
                    } else if dist == minDistance && i < bestSlot {
                        bestSlot = i
                    }
                }
            }
            if bestSlot != -1 {
                slotMap[overlay.id] = bestSlot
                filledSlots.insert(bestSlot)
            }
        }
        
        return slotMap
    }

    private func isOverlayHovered(id: String) -> Bool {
        let actual = OverlayStateRelay.shared.actualHoveredTypes
        let global = OverlayStateRelay.shared.globalHoveredTypes
        if actual.contains(id) || global.contains(id) { return true }
        for prefix in ["ram", "bluetooth", "peripheral", "display", "battery"] {
            if id.hasPrefix(prefix) && (actual.contains(prefix) || global.contains(prefix)) {
                return true
            }
        }
        return false
    }
    
    private func effectiveOverlayWidth(for overlay: ActiveOverlay) -> CGFloat {
        let enableMinimal = UserDefaults.standard.bool(forKey: "enableMinimalMode")
        if enableMinimal {
            if !isOverlayHovered(id: overlay.id) {
                return 140
            }
        }
        if overlay.type == .capsLock || overlay.type == .theme {
            return 230
        } else if overlay.type == .focus {
            return 240
        } else {
            return 260
        }
    }

    private func getSlotX(index: Int, totalSlots: Int, in size: CGSize) -> CGFloat {
        if totalSlots <= 1 {
            return size.width / 2
        }
        let margin: CGFloat = 40
        let enableMinimal = UserDefaults.standard.bool(forKey: "enableMinimalMode")
        let averageWidth: CGFloat = enableMinimal ? 140 : 260
        let availableWidth = size.width - 2 * margin
        let spacing = (availableWidth - CGFloat(totalSlots) * averageWidth) / CGFloat(totalSlots - 1)
        
        return margin + (averageWidth / 2) + CGFloat(index) * (averageWidth + spacing)
    }

    private func computeLayerPositions(overlays: [ActiveOverlay], limit: Int, size: CGSize) -> [String: CGFloat] {
        let lefts = overlays.filter { $0.position.hasSuffix("_left") }
        let rights = overlays.filter { $0.position.hasSuffix("_right") }
        let centers = overlays.filter { !$0.position.hasSuffix("_left") && !$0.position.hasSuffix("_right") }
        
        let enableMinimal = UserDefaults.standard.bool(forKey: "enableMinimalMode")
        let isAllMinimal = enableMinimal && overlays.allSatisfy { !isOverlayHovered(id: $0.id) }
        let s: CGFloat = isAllMinimal ? 12 : 20
        let marginVal = UserDefaults.standard.object(forKey: "overlayMargin")
        let m: CGFloat = marginVal != nil ? CGFloat((marginVal as? NSNumber)?.doubleValue ?? 30.0) : 30.0
        
        let countLeft = lefts.count
        let countCenter = centers.count
        let countRight = rights.count
        
        var currentX = m
        var leftPositions: [String: CGFloat] = [:]
        for overlay in lefts {
            let w = effectiveOverlayWidth(for: overlay)
            leftPositions[overlay.id] = currentX + (w / 2)
            currentX += w + s
        }
        let leftEnd = countLeft > 0 ? (currentX - s) : 0
        
        var currentRightX = size.width - m
        var rightPositions: [String: CGFloat] = [:]
        for overlay in rights {
            let w = effectiveOverlayWidth(for: overlay)
            rightPositions[overlay.id] = currentRightX - (w / 2)
            currentRightX -= (w + s)
        }
        let rightStart = countRight > 0 ? (currentRightX + s) : size.width
        
        let totalCenterWidth = centers.reduce(CGFloat(0)) { $0 + effectiveOverlayWidth(for: $1) } + CGFloat(max(0, countCenter - 1)) * s
        let centerStart = (size.width - totalCenterWidth) / 2
        let centerEnd = centerStart + totalCenterWidth
        
        var hasCollision = false
        if countLeft > 0 && countRight > 0 && countCenter == 0 {
            if leftEnd + s > rightStart { hasCollision = true }
        }
        if countCenter > 0 {
            if countLeft > 0 && (leftEnd + s > centerStart) { hasCollision = true }
            if countRight > 0 && (centerEnd + s > rightStart) { hasCollision = true }
        }
        
        var result: [String: CGFloat] = [:]
        
        if !hasCollision {
            result.merge(leftPositions) { (current, _) in current }
            result.merge(rightPositions) { (current, _) in current }
            
            var currentCenterX = centerStart
            for overlay in centers {
                let w = effectiveOverlayWidth(for: overlay)
                result[overlay.id] = currentCenterX + (w / 2)
                currentCenterX += w + s
            }
        } else {
            let slotMap = assignSlots(overlays: overlays, limit: limit)
            for (id, slotIndex) in slotMap {
                result[id] = getSlotX(index: slotIndex, totalSlots: limit, in: size)
            }
        }
        
        return result
    }

    private var heartbeatTimer: AnyCancellable?
    
    private init() {
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.cachedScreens = NSScreen.screens
                self.updateWindows()
            }
        }
        
        // Listen for overlay state changes (show/hide) via targeted notification.
        // This replaces the overly-broad objectWillChange.sink which fired on EVERY
        // MediaKeyManager property change (including settings edits in the dashboard).
        NotificationCenter.default.publisher(for: .visorProOverlayStateChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateWindows()
                self?.ensureHeartbeatRunning()
            }
            .store(in: &cancellables)
        
        // Only observe swipe-related properties (the only high-frequency state
        // that VisorProWindowManager needs beyond show/hide notifications).
        // Previously this was objectWillChange.sink which fired on ALL 177
        // @Published properties — causing massive UI thrashing.
        SwipeStateRelay.shared.$swipeOffsets
            .throttle(for: .milliseconds(16), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.updateWindows()
            }
            .store(in: &cancellables)
        
        SwipeStateRelay.shared.$activeSwipeIds
            .throttle(for: .milliseconds(16), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.updateWindows()
            }
            .store(in: &cancellables)
        
        OverlayStateRelay.shared.$actualHoveredTypes
            .throttle(for: .milliseconds(50), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.updateWindows()
            }
            .store(in: &cancellables)
        
        // Migrate legacy unconfigurable default ("default" / nil) to "fluid_bounce" for all users
        if UserDefaults.standard.object(forKey: "hasMigratedOverlayAnimationToFluid") == nil {
            if UserDefaults.standard.string(forKey: "overlayAnimationType") == nil || UserDefaults.standard.string(forKey: "overlayAnimationType") == "default" {
                UserDefaults.standard.set("fluid_bounce", forKey: "overlayAnimationType")
            }
            UserDefaults.standard.set(true, forKey: "hasMigratedOverlayAnimationToFluid")
        }
        
        // Start initial heartbeat — it will auto-stop when no panels are active
        ensureHeartbeatRunning()
    }
    
    /// Starts the 0.1s heartbeat timer if it's not already running.
    /// The timer auto-stops when there are no active overlay panels.
    private func ensureHeartbeatRunning() {
        guard heartbeatTimer == nil else { return }
        heartbeatTimer = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.windows.isEmpty {
                    // No active panels — stop the heartbeat to save CPU
                    self.heartbeatTimer?.cancel()
                    self.heartbeatTimer = nil
                } else if self.animatingEntryPanels.isEmpty && self.exitingPanels.isEmpty {
                    self.updateWindows()
                }
            }
    }
    
    struct ActiveOverlay: Identifiable, Equatable {
        let id: String
        let type: ContentView.OverlayType
        let position: String
        let notification: DeviceNotification?
        
        static func == (lhs: ActiveOverlay, rhs: ActiveOverlay) -> Bool {
            lhs.id == rhs.id && lhs.type == rhs.type && lhs.notification == rhs.notification
        }
    }
    
    var allActiveOverlays: [ActiveOverlay] {
        let relay = OverlayStateRelay.shared
        var active: [ActiveOverlay] = []
        
        let volumeOverlayPosition = MediaKeyManager.shared.getOverlayPosition(for: "volumeOverlayPosition")
        let batteryOverlayPosition = MediaKeyManager.shared.getOverlayPosition(for: "batteryOverlayPosition")
        let brightnessOverlayPosition = MediaKeyManager.shared.getOverlayPosition(for: "brightnessOverlayPosition")
        let keyboardBrightnessOverlayPosition = MediaKeyManager.shared.getOverlayPosition(for: "keyboardBrightnessOverlayPosition")
        let copyOverlayPosition = MediaKeyManager.shared.getOverlayPosition(for: "copyOverlayPosition")
        let capsLockOverlayPosition = MediaKeyManager.shared.getOverlayPosition(for: "capsLockOverlayPosition")
        
        let showBattery = relay.showChargingStatus || relay.showLowBatteryWarning || relay.showUnpluggedStatus
        
        if relay.showVolumeIndicator { active.append(ActiveOverlay(id: "volume", type: .volume, position: volumeOverlayPosition, notification: nil)) }
        if relay.showBrightnessIndicator { active.append(ActiveOverlay(id: "brightness", type: .brightness, position: brightnessOverlayPosition, notification: nil)) }
        if relay.showKeyboardBrightnessIndicator { active.append(ActiveOverlay(id: "keyboardBrightness", type: .keyboardBrightness, position: keyboardBrightnessOverlayPosition, notification: nil)) }
        if showBattery { 
            let batId = (relay.showLowBatteryWarning && !relay.isPluggedIn) ? "battery_warning" : "battery_charging"
            active.append(ActiveOverlay(id: batId, type: .battery, position: batteryOverlayPosition, notification: nil)) 
        }
        if relay.showCopyIndicator { active.append(ActiveOverlay(id: "copy", type: .copy, position: copyOverlayPosition, notification: nil)) }
        if relay.showCapsLockIndicator { active.append(ActiveOverlay(id: "capsLock", type: .capsLock, position: capsLockOverlayPosition, notification: nil)) }
        let surveyOverlayPosition = MediaKeyManager.shared.getOverlayPosition(for: "surveyOverlayPosition")
        if relay.showSurveyIndicator { active.append(ActiveOverlay(id: "survey", type: .survey, position: surveyOverlayPosition, notification: nil)) }
        
        let btPos = MediaKeyManager.shared.getOverlayPosition(for: "bluetoothOverlayPosition")
        for notif in relay.activeBluetoothNotifications {
            active.append(ActiveOverlay(id: "bluetooth_\(notif.id)", type: .bluetooth, position: btPos, notification: notif))
        }
        
        if relay.showSmartRoutingIndicator {
            active.append(ActiveOverlay(id: "smartRouting", type: .smartRouting, position: btPos, notification: nil))
        }
        
        let langPos = MediaKeyManager.shared.getOverlayPosition(for: "languageOverlayPosition")
        if relay.showLanguageIndicator { active.append(ActiveOverlay(id: "language", type: .language, position: langPos, notification: nil)) }
        
        let mediaPos = MediaKeyManager.shared.getOverlayPosition(for: "mediaOverlayPosition")
        if relay.showMediaIndicator { active.append(ActiveOverlay(id: "media", type: .media, position: mediaPos, notification: nil)) }
        
        let themePos = MediaKeyManager.shared.getOverlayPosition(for: "themeOverlayPosition")
        if relay.showThemeIndicator { active.append(ActiveOverlay(id: "theme", type: .theme, position: themePos, notification: nil)) }
        
        let focusPos = MediaKeyManager.shared.getOverlayPosition(for: "focusOverlayPosition")
        if relay.showFocusIndicator { active.append(ActiveOverlay(id: "focus", type: .focus, position: focusPos, notification: nil)) }
        
        let micPos = MediaKeyManager.shared.getOverlayPosition(for: "micOverlayPosition")
        if relay.showMicIndicator { active.append(ActiveOverlay(id: "mic", type: .mic, position: micPos, notification: nil)) }
        
        let camPos = MediaKeyManager.shared.getOverlayPosition(for: "cameraOverlayPosition")
        if relay.showCameraIndicator { active.append(ActiveOverlay(id: "camera", type: .camera, position: camPos, notification: nil)) }
        
        let locPos = MediaKeyManager.shared.getOverlayPosition(for: "locationOverlayPosition")
        if relay.showLocationIndicator { active.append(ActiveOverlay(id: "location", type: .location, position: locPos, notification: nil)) }
        
        let wifiPos = MediaKeyManager.shared.getOverlayPosition(for: "wifiOverlayPosition")
        if relay.showWiFiIndicator { active.append(ActiveOverlay(id: "wifi", type: .wifi, position: wifiPos, notification: nil)) }
        
        let datePos = MediaKeyManager.shared.getOverlayPosition(for: "dateOverlayPosition")
        if relay.showDateIndicator { active.append(ActiveOverlay(id: "date", type: .date, position: datePos, notification: nil)) }
        
        let periPos = MediaKeyManager.shared.getOverlayPosition(for: "peripheralOverlayPosition")
        for notif in relay.activePeripheralNotifications {
            active.append(ActiveOverlay(id: "peripheral_\(notif.id)", type: .peripheral, position: periPos, notification: notif))
        }
        
        let displayPos = MediaKeyManager.shared.getOverlayPosition(for: "displayOverlayPosition")
        for notif in relay.activeDisplayNotifications {
            active.append(ActiveOverlay(id: "display_\(notif.id)", type: .display, position: displayPos, notification: notif))
        }
        
        
        let ramPos = MediaKeyManager.shared.getOverlayPosition(for: "ramOverlayPosition")
        if relay.showRamIndicator { active.append(ActiveOverlay(id: "ram", type: .ram, position: ramPos, notification: nil)) }
        let cpuPos = MediaKeyManager.shared.getOverlayPosition(for: "cpuOverlayPosition")
        if relay.showCpuIndicator { active.append(ActiveOverlay(id: "cpu", type: .cpu, position: cpuPos, notification: nil)) }
        let trashPos = MediaKeyManager.shared.getOverlayPosition(for: "trashOverlayPosition")
        if relay.showTrashIndicator { active.append(ActiveOverlay(id: "trash", type: .trash, position: trashPos, notification: nil)) }
        
        let fileDeletedPos = MediaKeyManager.shared.getOverlayPosition(for: "fileDeletedOverlayPosition")
        if relay.showFileDeletedIndicator { active.append(ActiveOverlay(id: "fileDeleted", type: .fileDeleted, position: fileDeletedPos, notification: nil)) }
        
        let accBatPos = MediaKeyManager.shared.getOverlayPosition(for: "batteryOverlayPosition")
        if relay.showAccessoryBatteryIndicator {
            active.append(ActiveOverlay(id: "accessoryBattery", type: .accessoryBattery, position: accBatPos, notification: nil))
        }
        if relay.showAirpodsGroupBatteryIndicator {
            active.append(ActiveOverlay(id: "airpodsGroupBattery", type: .airpodsGroupBattery, position: accBatPos, notification: nil))
        }
        
        if relay.showAirPodsModeIndicator {
            let pos = MediaKeyManager.shared.getOverlayPosition(for: "bluetoothOverlayPosition")
            active.append(ActiveOverlay(id: "airpodsMode", type: .airpodsMode, position: pos, notification: nil))
        }
        
        let limit = max(1, MediaKeyManager.shared.maxSimultaneousNotifications)
        
        let now = Date()
        for overlay in active {
            if let triggerTime = MediaKeyManager.shared.overlayTriggerTimes[overlay.id] {
                self.overlayTimestamps[overlay.id] = triggerTime
            } else if self.overlayTimestamps[overlay.id] == nil {
                self.overlayTimestamps[overlay.id] = now
            }
        }
        let activeIds = Set(active.map { $0.id })
        for id in self.overlayTimestamps.keys {
            if !activeIds.contains(id) {
                self.overlayTimestamps.removeValue(forKey: id)
            }
        }
        
        let topCandidates = active.filter { $0.position.hasPrefix("top") }
        let topToKeep = Set(topCandidates.sorted { (self.overlayTimestamps[$0.id] ?? now) > (self.overlayTimestamps[$1.id] ?? now) }.prefix(limit).map { $0.id })
            
        let bottomCandidates = active.filter { $0.position.hasPrefix("bottom") }
        let bottomToKeep = Set(bottomCandidates.sorted { (self.overlayTimestamps[$0.id] ?? now) > (self.overlayTimestamps[$1.id] ?? now) }.prefix(limit).map { $0.id })
            
        let centerCandidates = active.filter { !$0.position.hasPrefix("top") && !$0.position.hasPrefix("bottom") }
        let centerToKeep = Set(centerCandidates.sorted { (self.overlayTimestamps[$0.id] ?? now) > (self.overlayTimestamps[$1.id] ?? now) }.prefix(limit).map { $0.id })
            
        var finalActive: [ActiveOverlay] = []
        for overlay in active {
            if topToKeep.contains(overlay.id) || bottomToKeep.contains(overlay.id) || centerToKeep.contains(overlay.id) {
                finalActive.append(overlay)
            } else {
                Task { @MainActor in
                    MediaKeyManager.shared.forceHide(overlayId: overlay.id)
                }
            }
        }
        
        return finalActive
    }
    
    private func getCategoryForTelemetry(type: ContentView.OverlayType) -> String? {
        switch type {
        case .volume: return "Volume"
        case .brightness: return "Brightness"
        case .keyboardBrightness: return "Keyboard Brightness"
        case .battery, .accessoryBattery, .airpodsGroupBattery: return "Battery"
        case .copy: return "Clipboard"
        case .date: return "Date"
        case .media: return "Media"
        case .wifi: return "Wi-Fi"
        case .bluetooth, .airpodsMode: return "Bluetooth"
        case .mic, .camera, .location: return "Privacy"
        case .theme: return "Theme"
        case .focus: return "Focus Mode"
        case .peripheral: return "Peripherals"
        case .display: return "Displays"
        case .ram, .cpu: return "System"
        case .trash: return "Trash"
        default: return nil // Dropping survey, capsLock, fileDeleted, smartRouting, etc.
        }
    }
    
    func updateWindows() {
        let active = allActiveOverlays
        
        for overlay in active {
            if let triggerTime = self.overlayTimestamps[overlay.id] {
                if self.reportedTelemetryTimestamps[overlay.id] != triggerTime {
                    self.reportedTelemetryTimestamps[overlay.id] = triggerTime
                    if let cleanCategoryName = getCategoryForTelemetry(type: overlay.type) {
                        var params: [String: String] = ["overlay_type": cleanCategoryName]
                        if overlay.type == .focus {
                            let isDetailed = UserDefaults.standard.bool(forKey: "focusDetailMode")
                            params["focus_detailed_mode"] = isDetailed ? "true" : "false"
                            params["focus_mode_style"] = isDetailed ? "detailed" : "standard"
                        }
                        TelemetryDeck.signal("OverlayDisplayed", parameters: params)
                    }
                }
            }
        }
        
        var uniqueScreens: [NSScreen] = []
        var seenOrigins = Set<String>()
        for screen in cachedScreens {
            let originKey = "\(Int(screen.frame.origin.x)),\(Int(screen.frame.origin.y))"
            if !seenOrigins.contains(originKey) {
                seenOrigins.insert(originKey)
                uniqueScreens.append(screen)
            }
        }
        
        if OverlayStateRelay.shared.forceSingleScreenForDisplayTransition && !uniqueScreens.isEmpty {
            uniqueScreens = [uniqueScreens[0]]
        }
        
        let displayTarget = UserDefaults.standard.string(forKey: "overlayDisplayTarget") ?? "all"
        var finalScreens: [NSScreen] = []
        if displayTarget == "main" {
            if let mainScreen = uniqueScreens.first {
                finalScreens.append(mainScreen)
            }
        } else if displayTarget.starts(with: "screen_") {
            let targetIdStr = displayTarget.replacingOccurrences(of: "screen_", with: "")
            if let targetId = UInt32(targetIdStr),
               let screen = uniqueScreens.first(where: { ($0.deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as? CGDirectDisplayID) == targetId }) {
                finalScreens.append(screen)
            } else if let mainScreen = uniqueScreens.first { // fallback
                finalScreens.append(mainScreen)
            }
        } else {
            let mouseLoc = NSEvent.mouseLocation
            if let activeScreen = uniqueScreens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) {
                finalScreens = [activeScreen]
            } else if let mainScreen = uniqueScreens.first {
                finalScreens = [mainScreen]
            }
        }
        
        var targetWindowIds: Set<String> = []
        for overlay in active {
            for (screenIndex, _) in finalScreens.enumerated() {
                targetWindowIds.insert("\(overlay.id)_screen_\(screenIndex)")
            }
        }
        
        var rescuedPanels: Set<String> = []
        for (id, window) in windows {
            if !targetWindowIds.contains(id) {
                if exitingPanels.contains(id) { continue }
                
                let overlayId = String(id.split(separator: "_screen_").first ?? "")
                let isOverlayStillActive = active.contains { $0.id == overlayId }
                
                if isOverlayStillActive {
                    // Screen vanished. Hide immediately so macOS doesn't snap the orphaned window to the main display.
                    window.orderOut(nil)
                    window.contentView = nil
                    window.close()
                    windows.removeValue(forKey: id)
                    targetOrigins.removeValue(forKey: id)
                    shownPanels.remove(id)
                } else {
                    exitingPanels.insert(id)
                    let currentSwipeOffset = SwipeStateRelay.shared.swipeOffsets[overlayId] ?? 0.0
                    
                    if abs(currentSwipeOffset) > 30 {
                        NSAnimationContext.runAnimationGroup({ ctx in
                            ctx.duration = 0.1
                            window.animator().alphaValue = 0.0
                        }, completionHandler: {
                            Task { @MainActor in
                                window.orderOut(nil)
                                window.contentView = nil
                                window.close()
                                MediaKeyManager.shared.swipeOffsets[overlayId] = 0
                                self.windows.removeValue(forKey: id)
                                self.targetOrigins.removeValue(forKey: id)
                                self.shownPanels.remove(id)
                                self.exitingPanels.remove(id)
                            }
                        })
                    } else {
                        let animType = UserDefaults.standard.string(forKey: "overlayAnimationType") ?? "fluid_bounce"
                        
                        // Notify SwiftUI IMMEDIATELY (synchronously) so the view's exit animation begins on frame 0
                        OverlayStateRelay.shared.closingPanels.insert(overlayId)
                        
                        let exitDuration: Double
                        switch animType {
                        case "ripple", "flip":
                            exitDuration = 0.22
                        case "unfold", "pop", "scale":
                            exitDuration = 0.20
                        case "fluid_drop":
                            exitDuration = 0.24
                        default:
                            exitDuration = 0.18
                        }
                        
                        // Unified spatial & exit animation handled inside SingleOverlayContainer in SwiftUI
                        DispatchQueue.main.asyncAfter(deadline: .now() + exitDuration + 0.03) {
                            Task { @MainActor in
                                OverlayStateRelay.shared.closingPanels.remove(overlayId)
                                if self.exitingPanels.contains(id) {
                                    window.orderOut(nil)
                                    window.contentView = nil
                                    window.close()
                                    self.windows.removeValue(forKey: id)
                                    self.targetOrigins.removeValue(forKey: id)
                                    self.shownPanels.remove(id)
                                    self.exitingPanels.remove(id)
                                }
                            }
                        }
                    }
                }
            } else {
                if exitingPanels.contains(id) {
                    exitingPanels.remove(id)
                    rescuedPanels.insert(id)
                    let overlayId = String(id.split(separator: "_screen_").first ?? "")
                    DispatchQueue.main.async {
                        OverlayStateRelay.shared.closingPanels.remove(overlayId)
                    }
                }
            }
        }
        
        let limit = max(1, MediaKeyManager.shared.maxSimultaneousNotifications)
        let topOverlays = active.filter { $0.position.hasPrefix("top") }
        let bottomOverlays = active.filter { $0.position.hasPrefix("bottom") }
        let centerOverlays = active.filter { !$0.position.hasPrefix("top") && !$0.position.hasPrefix("bottom") }
        
        for (screenIndex, screen) in finalScreens.enumerated() {
            let screenSize = screen.visibleFrame.size
            let screenOrigin = screen.visibleFrame.origin
            
            let topPositions = computeLayerPositions(overlays: topOverlays, limit: limit, size: screenSize)
            let bottomPositions = computeLayerPositions(overlays: bottomOverlays, limit: limit, size: screenSize)
            let centerPositions = computeLayerPositions(overlays: centerOverlays, limit: limit, size: screenSize)
            
            var allPositions = topPositions.merging(bottomPositions) { (current, _) in current }
            allPositions = allPositions.merging(centerPositions) { (current, _) in current }
            
            for overlay in active {
                let windowId = "\(overlay.id)_screen_\(screenIndex)"
                
                let panel: NSPanel
                if let existing = windows[windowId] {
                    panel = existing
                } else {
                    panel = createPanel(for: overlay)
                    windows[windowId] = panel
                }
                
                let theme = MediaKeyManager.shared.overlayTheme
                if theme == "dark" {
                    panel.appearance = NSAppearance(named: .darkAqua)
                } else if theme == "light" {
                    panel.appearance = NSAppearance(named: .aqua)
                } else {
                    panel.appearance = nil
                }
                
                let x = (allPositions[overlay.id] ?? (screenSize.width / 2)) + screenOrigin.x
                let yCenter = yPos(for: overlay.position, in: screenSize) + screenOrigin.y
                
                let currentWidth = panel.frame.width
                let currentHeight = panel.frame.height
                
                let originX = x - (currentWidth / 2)
                
                let originY: CGFloat
                if overlay.position.hasPrefix("top") {
                    originY = (yCenter + 44) - currentHeight
                } else if overlay.position.hasPrefix("bottom") {
                    originY = yCenter - 44
                } else {
                    originY = yCenter - (currentHeight / 2)
                }
                
                let swipeOffset = SwipeStateRelay.shared.swipeOffsets[overlay.id] ?? 0.0
                let originY_withOffset = originY - swipeOffset
                
                let targetOrigin = NSPoint(x: originX, y: originY_withOffset)
                
                if let last = targetOrigins[windowId], abs(last.y - originY) > 2000 {
                    let stalePanel = windows[windowId]
                    stalePanel?.orderOut(nil)
                    stalePanel?.contentView = nil
                    stalePanel?.close()
                    windows.removeValue(forKey: windowId)
                    targetOrigins.removeValue(forKey: windowId)
                    shownPanels.remove(windowId)
                }
                
                let isFirstShow = !shownPanels.contains(windowId)
                let logicalTarget = NSPoint(x: x, y: yCenter - swipeOffset)
                
                if isFirstShow {
                    shownPanels.insert(windowId)
                    targetOrigins[windowId] = targetOrigin
                    logicalTargetOrigins[windowId] = logicalTarget
                    animatingEntryPanels.insert(windowId)
                    
                    let animType = UserDefaults.standard.string(forKey: "overlayAnimationType") ?? "fluid_bounce"
                    let entryDuration: Double = (animType == "fluid_drop" ? 0.28 : 0.18)
                    
                    panel.alphaValue = 0.0
                    panel.setFrame(NSRect(origin: targetOrigin, size: CGSize(width: currentWidth, height: currentHeight)), display: true)
                    panel.orderFront(nil)
                    
                    panel.contentView?.layoutSubtreeIfNeeded()
                    panel.displayIfNeeded()
                    
                    DispatchQueue.main.async {
                        NSAnimationContext.runAnimationGroup({ ctx in
                            ctx.duration = entryDuration
                            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                            panel.animator().alphaValue = 1.0 - (abs(swipeOffset) / 60.0)
                        }, completionHandler: {
                            Task { @MainActor in
                                self.animatingEntryPanels.remove(windowId)
                            }
                        })
                    }
                } else if !MediaKeyManager.shared.isDisplayTransitioning && !animatingEntryPanels.contains(windowId) {
                    let isRescued = rescuedPanels.contains(windowId)
                    
                    let lastLogicalTarget = logicalTargetOrigins[windowId] ?? logicalTarget
                    let logicalDist = hypot(lastLogicalTarget.x - logicalTarget.x, lastLogicalTarget.y - logicalTarget.y)
                    logicalTargetOrigins[windowId] = logicalTarget
                    
                    let swipeActive = abs(swipeOffset) > 0.1
                    
                    if logicalDist > 1.0 || swipeActive || isRescued {
                        targetOrigins[windowId] = targetOrigin
                        let isDragging = SwipeStateRelay.shared.activeSwipeIds.contains(overlay.id)
                        
                        if isDragging {
                            panel.setFrame(NSRect(origin: targetOrigin, size: CGSize(width: currentWidth, height: currentHeight)), display: false)
                            panel.alphaValue = 1.0 - (abs(swipeOffset) / 60.0)
                        } else {
                            NSAnimationContext.runAnimationGroup { ctx in
                                ctx.duration = 0.25
                                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
                                panel.animator().setFrame(NSRect(origin: targetOrigin, size: CGSize(width: currentWidth, height: currentHeight)), display: false)
                                panel.animator().alphaValue = 1.0 - (abs(swipeOffset) / 60.0)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func createPanel(for overlay: ActiveOverlay) -> NSPanel {
        let w: CGFloat
        let h: CGFloat
        
        if overlay.type == .capsLock || overlay.type == .theme {
            w = 230
        } else if overlay.type == .focus {
            w = 240
        } else {
            w = 260
        }
        
        if overlay.type == .battery {
            let manager = MediaKeyManager.shared
            let isFullyCharged = manager.currentBatteryPercentage == 100 || manager.isEffectivelyFullyCharged
            h = isFullyCharged ? 56 : 72
        } else if overlay.type == .airpodsGroupBattery {
            h = 134
        } else if overlay.type == .media {
            h = 72
        } else if overlay.type == .survey {
            let relay = OverlayStateRelay.shared
            let questionId = relay.activeSurveyQuestionId
            let question = SurveyLibrary.shared.questions.first(where: { $0.id == questionId }) ?? SurveyLibrary.shared.questions.first
            h = question?.height ?? 180
        } else {
            h = 56
        }
        
        let panel = VisorProOverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: w + 32, height: h + 32),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.animationBehavior = .none
        
        if overlay.position.hasPrefix("top") {
            panel.anchorMode = .top
        } else if overlay.position.hasPrefix("bottom") {
            panel.anchorMode = .bottom
        } else {
            panel.anchorMode = .center
        }
        
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        
        let view = SingleOverlayContainer(overlay: overlay)
            .environmentObject(MediaKeyManager.shared)
            .environmentObject(OverlayStateRelay.shared)
        let hostingView = TrackingHostingView(rootView: view)
        hostingView.overlayId = overlay.id
        panel.contentView = hostingView
        
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        
        return panel
    }
    
    private func yPos(for position: String, in size: CGSize) -> CGFloat {
        let marginVal = UserDefaults.standard.object(forKey: "overlayMargin"); let margin = marginVal != nil ? CGFloat((marginVal as? NSNumber)?.doubleValue ?? 30.0) : 30.0
        let bottomPadding: CGFloat = margin
        let topPadding: CGFloat = margin
        let pillHeight: CGFloat = 56
        if position.hasPrefix("top") { return size.height - topPadding - (pillHeight / 2) } 
        if position == "center" { return size.height / 2 }
        return bottomPadding + (pillHeight / 2)
    }

    func isWindowUnderMouse(for overlayId: String) -> Bool {
        let mouseLoc = NSEvent.mouseLocation
        
        for (key, panel) in windows {
            guard key.hasPrefix(overlayId) else { continue }
            guard panel.isVisible else { continue }
            let visibleFrame = panel.frame.insetBy(dx: 16, dy: 16)
            if visibleFrame.contains(mouseLoc) {
                return true
            }
        }
        
        return false
    }

    func isOverlayHit(by event: NSEvent, overlayId: String) -> Bool {
        if let eventWindow = event.window {
            if let match = windows.first(where: { $0.value === eventWindow }), match.key.hasPrefix(overlayId) {
                let localPoint = event.locationInWindow
                let pillBounds = NSRect(origin: .zero, size: eventWindow.frame.size).insetBy(dx: 16, dy: 16)
                if pillBounds.contains(localPoint) {
                    return true
                }
            }
        }
        
        return isWindowUnderMouse(for: overlayId)
    }
}

enum WindowAnchorMode {
    case top
    case bottom
    case center
}

class VisorProOverlayPanel: NSPanel {
    var anchorMode: WindowAnchorMode = .center
    
    private var stableMaxY: CGFloat?
    private var stableMinY: CGFloat?
    private var stableMidY: CGFloat?
    
    override var canBecomeKey: Bool { return false }
    override var canBecomeMain: Bool { return false }
    
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
    
    private func adjustFrame(_ frameRect: NSRect) -> NSRect {
        var newFrame = frameRect
        let oldFrame = self.frame
        
        let isResize = oldFrame.size.height > 0 && oldFrame.size.height != newFrame.size.height
        
        if isResize {
            switch anchorMode {
            case .bottom:
                let minY = stableMinY ?? oldFrame.minY
                newFrame.origin.y = round(minY)
                stableMinY = minY
            case .top:
                let maxY = stableMaxY ?? oldFrame.maxY
                newFrame.origin.y = round(maxY - newFrame.height)
                stableMaxY = maxY
            case .center:
                let midY = stableMidY ?? oldFrame.midY
                newFrame.origin.y = round(midY - (newFrame.height / 2))
                stableMidY = midY
            }
        } else {
            stableMinY = newFrame.minY
            stableMaxY = newFrame.maxY
            stableMidY = newFrame.midY
        }
        
        return newFrame
    }
    
    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        let newFrame = adjustFrame(frameRect)
        super.setFrame(newFrame, display: flag)
    }
    
    override func setFrame(_ frameRect: NSRect, display flag: Bool, animate: Bool) {
        let newFrame = adjustFrame(frameRect)
        super.setFrame(newFrame, display: flag, animate: animate)
    }
}

class TrackingHostingView<Content: View>: NSHostingView<Content> {
    var overlayId: String?
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    override func rightMouseDown(with event: NSEvent) {
        if handleSecondaryClick(event: event) {
            return
        }
        super.rightMouseDown(with: event)
    }
    
    override func otherMouseDown(with event: NSEvent) {
        if handleSecondaryClick(event: event) {
            return
        }
        super.otherMouseDown(with: event)
    }
    
    private func handleSecondaryClick(event: NSEvent) -> Bool {
        let enable = UserDefaults.standard.object(forKey: "enableThreeFingerClickToDismiss") as? Bool ?? (UserDefaults.standard.object(forKey: "enableTwoFingerClickToDismiss") as? Bool ?? true)
        guard enable, let overlayId = overlayId else { return false }
        
        let pillBounds = NSRect(origin: .zero, size: self.frame.size).insetBy(dx: 16, dy: 16)
        if pillBounds.contains(event.locationInWindow) || VisorProWindowManager.shared.isWindowUnderMouse(for: overlayId) {
            MediaKeyManager.shared.forceHide(overlayId: overlayId)
            return true
        }
        return false
    }
}

struct SingleOverlayContainer: View {
    let overlay: VisorProWindowManager.ActiveOverlay
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @EnvironmentObject var stateRelay: OverlayStateRelay
    @State private var appearScaleX: CGFloat
    @State private var appearScaleY: CGFloat
    @State private var appearBlur: CGFloat
    @State private var appearOffset: CGFloat
    @State private var appearAngle: Double
    @State private var appearOpacity: Double
    @State private var appearCornerRadius: CGFloat
    private var animType: String {
        UserDefaults.standard.string(forKey: "overlayAnimationType") ?? "fluid_bounce"
    }
    
    private var targetCornerRadius: CGFloat {
        (52.0 / 2.0) * CGFloat(mediaKeyManager.cornerRoundingMultiplier)
    }
    
    init(overlay: VisorProWindowManager.ActiveOverlay) {
        self.overlay = overlay
        let anim = UserDefaults.standard.string(forKey: "overlayAnimationType") ?? "fluid_bounce"
        let isTop = overlay.position.hasPrefix("top")
        let verticalOffset: CGFloat = isTop ? -40.0 : 40.0
        
        switch anim {
        case "fluid_drop":
            _appearScaleX = State(initialValue: 0.0846)
            _appearScaleY = State(initialValue: 0.4231)
            _appearBlur = State(initialValue: 5.0)
            _appearOffset = State(initialValue: isTop ? -50.0 : 50.0)
            _appearAngle = State(initialValue: 0.0)
            _appearOpacity = State(initialValue: 0.0)
            _appearCornerRadius = State(initialValue: 26.0)
        case "scale":
            _appearScaleX = State(initialValue: 0.6)
            _appearScaleY = State(initialValue: 0.6)
            _appearBlur = State(initialValue: 15.0)
            _appearOffset = State(initialValue: 0.0)
            _appearAngle = State(initialValue: 0.0)
            _appearOpacity = State(initialValue: 0.0)
            _appearCornerRadius = State(initialValue: 26.0)
        case "fluid_bounce":
            _appearScaleX = State(initialValue: 0.3)
            _appearScaleY = State(initialValue: 0.3)
            _appearBlur = State(initialValue: 0.0)
            _appearOffset = State(initialValue: isTop ? -35.0 : 35.0)
            _appearAngle = State(initialValue: 0.0)
            _appearOpacity = State(initialValue: 0.0)
            _appearCornerRadius = State(initialValue: 26.0)
        case "ripple":
            _appearScaleX = State(initialValue: 0.08)
            _appearScaleY = State(initialValue: 1.0)
            _appearBlur = State(initialValue: 8.0)
            _appearOffset = State(initialValue: 0.0)
            _appearAngle = State(initialValue: 0.0)
            _appearOpacity = State(initialValue: 0.0)
            _appearCornerRadius = State(initialValue: 26.0)
        case "flip":
            _appearScaleX = State(initialValue: 1.0)
            _appearScaleY = State(initialValue: 1.0)
            _appearBlur = State(initialValue: 4.0)
            _appearOffset = State(initialValue: 0.0)
            _appearAngle = State(initialValue: isTop ? -75.0 : 75.0)
            _appearOpacity = State(initialValue: 0.0)
            _appearCornerRadius = State(initialValue: 26.0)
        case "unfold":
            _appearScaleX = State(initialValue: 1.0)
            _appearScaleY = State(initialValue: 0.03)
            _appearBlur = State(initialValue: 6.0)
            _appearOffset = State(initialValue: 0.0)
            _appearAngle = State(initialValue: 0.0)
            _appearOpacity = State(initialValue: 0.0)
            _appearCornerRadius = State(initialValue: 26.0)
        case "pop":
            _appearScaleX = State(initialValue: 0.75)
            _appearScaleY = State(initialValue: 0.35)
            _appearBlur = State(initialValue: 4.0)
            _appearOffset = State(initialValue: isTop ? -35.0 : 35.0)
            _appearAngle = State(initialValue: 0.0)
            _appearOpacity = State(initialValue: 0.0)
            _appearCornerRadius = State(initialValue: 26.0)
        default:
            _appearScaleX = State(initialValue: 1.0)
            _appearScaleY = State(initialValue: 1.0)
            _appearBlur = State(initialValue: 0.0)
            _appearOffset = State(initialValue: verticalOffset)
            _appearAngle = State(initialValue: 0.0)
            _appearOpacity = State(initialValue: 0.0)
            _appearCornerRadius = State(initialValue: 26.0)
        }
    }
    
    var body: some View {
        let isTop = overlay.position.hasPrefix("top")
        let isBottom = overlay.position.hasPrefix("bottom")
        let anchor: UnitPoint = isTop ? .top : (isBottom ? .bottom : .center)
        
        ZStack(alignment: isTop ? .top : (isBottom ? .bottom : .center)) {
            overlayView(for: overlay)
                .applyTheme(mediaKeyManager.overlayTheme)
                .swipeToDismiss(overlayId: overlay.id, isTopPosition: isTop)
                .threeFingerClickToDismiss(overlayId: overlay.id)
                .rotation3DEffect(
                    .degrees(appearAngle),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: anchor,
                    perspective: 0.45
                )
                .scaleEffect(x: appearScaleX, y: appearScaleY)
                .blur(radius: appearBlur)
                .offset(y: appearOffset)
                .opacity(appearOpacity)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isTop ? .top : (isBottom ? .bottom : .center))
        .onAppear {
            let isTop = overlay.position.hasPrefix("top")
            
            if animType == "scale" {
                appearScaleX = 0.6
                appearScaleY = 0.6
                appearBlur = 15.0
                appearOpacity = 0.0
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.12)) {
                        appearOpacity = 1.0
                    }
                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 20)) {
                        appearScaleX = 1.0
                        appearScaleY = 1.0
                        appearBlur = 0.0
                    }
                }
            } else if animType == "fluid_bounce" {
                appearScaleX = 0.3
                appearScaleY = 0.3
                appearOffset = isTop ? -35.0 : 35.0
                appearBlur = 0.0
                appearOpacity = 0.0
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.12)) {
                        appearOpacity = 1.0
                    }
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
                        appearScaleX = 1.0
                        appearScaleY = 1.0
                        appearOffset = 0.0
                    }
                }
            } else if animType == "fluid_drop" {
                appearScaleX = 0.0846
                appearScaleY = 0.4231
                appearBlur = 5.0
                appearCornerRadius = 26.0
                appearOffset = isTop ? -50.0 : 50.0
                appearOpacity = 0.0
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                        appearOffset = 0.0
                        appearOpacity = 1.0
                        appearScaleX = 1.0
                        appearScaleY = 1.0
                        appearBlur = 0.0
                        appearCornerRadius = targetCornerRadius
                    }
                }
            } else if animType == "ripple" {
                appearScaleX = 0.08
                appearScaleY = 1.0
                appearBlur = 8.0
                appearOffset = 0.0
                appearAngle = 0.0
                appearOpacity = 0.0
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.12)) {
                        appearOpacity = 1.0
                    }
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.60)) {
                        appearScaleX = 1.0
                        appearBlur = 0.0
                    }
                }
            } else if animType == "flip" {
                appearScaleX = 1.0
                appearScaleY = 1.0
                appearBlur = 4.0
                appearOffset = 0.0
                appearAngle = isTop ? -75.0 : 75.0
                appearOpacity = 0.0
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.10)) {
                        appearOpacity = 1.0
                    }
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                        appearAngle = 0.0
                        appearBlur = 0.0
                    }
                }
            } else if animType == "unfold" {
                appearScaleX = 1.0
                appearScaleY = 0.03
                appearBlur = 6.0
                appearOffset = 0.0
                appearAngle = 0.0
                appearOpacity = 0.0
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.10)) {
                        appearOpacity = 1.0
                    }
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.62)) {
                        appearScaleY = 1.0
                        appearBlur = 0.0
                    }
                }
            } else if animType == "pop" {
                appearScaleX = 0.75
                appearScaleY = 0.35
                appearBlur = 4.0
                appearOffset = isTop ? -35.0 : 35.0
                appearAngle = 0.0
                appearOpacity = 0.0
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.10)) {
                        appearOpacity = 1.0
                    }
                    withAnimation(.spring(response: 0.40, dampingFraction: 0.55)) {
                        appearScaleX = 1.0
                        appearScaleY = 1.0
                        appearOffset = 0.0
                        appearBlur = 0.0
                    }
                }
            } else {
                // Default Slide
                appearScaleX = 1.0
                appearScaleY = 1.0
                appearBlur = 0.0
                appearOffset = isTop ? -40.0 : 40.0
                appearOpacity = 0.0
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.18)) {
                        appearOffset = 0.0
                        appearOpacity = 1.0
                    }
                }
            }
        }
        .onChange(of: stateRelay.closingPanels.contains(overlay.id)) { oldValue, isClosing in
            let isTop = overlay.position.hasPrefix("top")
            if isClosing {
                if animType == "scale" {
                    withAnimation(.easeIn(duration: 0.20)) {
                        appearScaleX = 0.6
                        appearScaleY = 0.6
                        appearBlur = 15.0
                        appearOpacity = 0.0
                    }
                } else if animType == "fluid_bounce" {
                    withAnimation(.easeIn(duration: 0.20)) {
                        appearScaleX = 0.3
                        appearScaleY = 0.3
                        appearOffset = isTop ? -35.0 : 35.0
                        appearBlur = 0.0
                        appearOpacity = 0.0
                    }
                } else if animType == "fluid_drop" {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.75)) {
                        appearScaleX = 0.0846
                        appearScaleY = 0.4231
                        appearBlur = 5.0
                        appearCornerRadius = 26.0
                        appearOffset = isTop ? -50.0 : 50.0
                        appearOpacity = 0.0
                    }
                } else if animType == "ripple" {
                    withAnimation(.easeIn(duration: 0.22)) {
                        appearScaleX = 0.08
                        appearScaleY = 1.0
                        appearBlur = 8.0
                        appearOpacity = 0.0
                    }
                } else if animType == "flip" {
                    withAnimation(.easeIn(duration: 0.22)) {
                        appearAngle = isTop ? -75.0 : 75.0
                        appearBlur = 4.0
                        appearOpacity = 0.0
                    }
                } else if animType == "unfold" {
                    withAnimation(.easeIn(duration: 0.20)) {
                        appearScaleX = 1.0
                        appearScaleY = 0.03
                        appearBlur = 6.0
                        appearOpacity = 0.0
                    }
                } else if animType == "pop" {
                    withAnimation(.easeIn(duration: 0.20)) {
                        appearScaleX = 0.75
                        appearScaleY = 0.35
                        appearOffset = isTop ? -35.0 : 35.0
                        appearBlur = 4.0
                        appearOpacity = 0.0
                    }
                } else {
                    // Default Slide
                    withAnimation(.easeIn(duration: 0.18)) {
                        appearOffset = isTop ? -40.0 : 40.0
                        appearOpacity = 0.0
                    }
                }
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    appearScaleX = 1.0
                    appearScaleY = 1.0
                    appearBlur = 0.0
                    appearAngle = 0.0
                    appearOffset = 0.0
                    appearOpacity = 1.0
                    appearCornerRadius = targetCornerRadius
                }
            }
        }
    }
    
    @ViewBuilder
    private func overlayView(for overlay: VisorProWindowManager.ActiveOverlay) -> some View {
        switch overlay.type {
        case .volume: VolumeOverlayView()
        case .brightness: BrightnessOverlayView()
        case .keyboardBrightness: KeyboardBrightnessOverlayView()
        case .battery: BatteryOverlayView(isWarningMode: mediaKeyManager.showLowBatteryWarning && !mediaKeyManager.isPluggedIn)
        case .copy: CopyOverlayView()
        case .capsLock: CapsLockOverlayView()
        case .bluetooth: BluetoothOverlayView(notification: overlay.notification)
        case .airpodsMode: AirPodsModeOverlayView()
        case .language: LanguageOverlayView()
        case .media: MediaOverlayView()
        case .theme: ThemeOverlayView()
        case .focus: FocusOverlayView()
        case .mic: MicOverlayView()
        case .camera: CameraOverlayView()
        case .location: LocationOverlayView()
        case .wifi: WiFiOverlayView()
        case .date: DateOverlayView()
        case .peripheral: PeripheralOverlayView(notification: overlay.notification)
        case .display: DisplayOverlayView(notification: overlay.notification)
        case .ram: RamOverlayView()
        case .accessoryBattery: AccessoryBatteryOverlayView()
        case .airpodsGroupBattery: AirPodsGroupBatteryOverlayView()
        case .cpu: CpuTemperatureOverlayView(isPreview: false)
        case .trash: TrashOverlayView()
        case .fileDeleted: FileDeletedOverlayView()
        case .smartRouting: SmartRoutingOverlayView()
        case .survey: SurveyOverlayView()
        }
    }
}

struct ScrollSwipeModifier: ViewModifier {
    let overlayId: String
    let isTopPosition: Bool
    
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("enableSwipeToDismiss") private var enableSwipeToDismiss = true
    @AppStorage("reverseSwipeDirection") private var reverseSwipeDirection = false
    
    @State private var totalScrollDelta: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDismissing = false
    
    @State private var globalMonitor: Any?
    @State private var localMonitor: Any?
    @State private var debounceTimer: Timer?

    func body(content: Content) -> some View {
        content
            .onAppear {
                isDismissing = false
                dragOffset = 0
                totalScrollDelta = 0
                SwipeStateRelay.shared.swipeOffsets[overlayId] = 0
                setupMonitors()
            }
            .onDisappear {
                removeMonitors()
                SwipeStateRelay.shared.swipeOffsets[overlayId] = 0
            }
    }
    
    private func handleScroll(event: NSEvent) {
        let enableSwipe = UserDefaults.standard.object(forKey: "enableSwipeToDismiss") as? Bool ?? true
        guard enableSwipe else { return }
        guard !isDismissing else { return }
        
        let isHovered = mediaKeyManager.actualHoveredTypes.contains(overlayId) ||
                        (overlayId.hasPrefix("ram") && mediaKeyManager.actualHoveredTypes.contains("ram")) ||
                        (overlayId.hasPrefix("bluetooth") && mediaKeyManager.actualHoveredTypes.contains("bluetooth")) ||
                        (overlayId.hasPrefix("peripheral") && mediaKeyManager.actualHoveredTypes.contains("peripheral")) ||
                        (overlayId.hasPrefix("display") && mediaKeyManager.actualHoveredTypes.contains("display"))
        
        // We rely entirely on the precise onHoverExact system from UniversalOverlayView,
        // which perfectly tracks the interface edges (globalHoveredTypes), ignoring the hidden NSWindow area.
        var isCurrentlySwiping = SwipeStateRelay.shared.activeSwipeIds.contains(overlayId)
        
        let phase = event.phase
        let momentum = event.momentumPhase
        
        if phase == .began && !isHovered {
            SwipeStateRelay.shared.activeSwipeIds.remove(overlayId)
            isCurrentlySwiping = false
        }
        

        guard isHovered || isCurrentlySwiping else { return }
        if !isCurrentlySwiping && OverlayStateRelay.shared.isHoveringScrollView { return }
        
        let rawDelta = event.scrollingDeltaY
        var deltaY = event.isDirectionInvertedFromDevice ? rawDelta : -rawDelta
        
        let reverseSwipe = UserDefaults.standard.bool(forKey: "reverseSwipeDirection")
        if reverseSwipe {
            deltaY = -deltaY
        }
        
        let isEnding = phase == .ended || phase == .cancelled || momentum == .ended || momentum == .cancelled
        if isEnding {
            SwipeStateRelay.shared.activeSwipeIds.remove(overlayId)
            debounceTimer?.invalidate()
            guard !isDismissing else { return }
            dragOffset = 0
            totalScrollDelta = 0
            SwipeStateRelay.shared.swipeOffsets[overlayId] = 0
            mediaKeyManager.keepAlive(for: overlayId, isHovering: isHovered)
            return
        }
        
        guard abs(deltaY) > 0.5 else { return }
        
        totalScrollDelta += deltaY
        
        if abs(totalScrollDelta) > 10 {
            SwipeStateRelay.shared.activeSwipeIds.insert(overlayId)
            mediaKeyManager.keepAlive(for: overlayId, isHovering: true)
        }
        
        var offset = totalScrollDelta
        
        if isTopPosition {
            if offset > 0 {
                if totalScrollDelta > 0 { totalScrollDelta = 0 }
                offset = 0
            } else if offset < -12 {
                offset += 12
            } else {
                offset = 0
            }
        } else {
            if offset > 12 {
                offset -= 12
            } else {
                if totalScrollDelta < 0 { totalScrollDelta = 0 }
                offset = 0
            }
        }
        
        dragOffset = offset
        
        let isOverThreshold = isTopPosition ? (dragOffset < -60) : (dragOffset > 60)
        
        if isOverThreshold && !isDismissing {
            isDismissing = true
            mediaKeyManager.forceHide(overlayId: overlayId)
            SwipeStateRelay.shared.activeSwipeIds.remove(overlayId)
        }
        
        // Always and consistently assign the current delta (which grows from the finger or from inertial momentum).
        SwipeStateRelay.shared.swipeOffsets[overlayId] = dragOffset
        
        if !isDismissing {
            if phase.rawValue == 0 && momentum.rawValue == 0 {
                debounceTimer?.invalidate()
                debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                    Task { @MainActor in
                        guard !isDismissing else { return }
                        SwipeStateRelay.shared.activeSwipeIds.remove(overlayId)
                        dragOffset = 0
                        totalScrollDelta = 0
                        SwipeStateRelay.shared.swipeOffsets[overlayId] = 0
                    }
                }
            }
        }
    }
    
    private func setupMonitors() {
        removeMonitors()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { event in
            handleScroll(event: event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            handleScroll(event: event)
            return event
        }
    }
    
    private func removeMonitors() {
        if let g = globalMonitor { NSEvent.removeMonitor(g); globalMonitor = nil }
        if let l = localMonitor { NSEvent.removeMonitor(l); localMonitor = nil }
    }
}

extension View {
    func swipeToDismiss(overlayId: String, isTopPosition: Bool) -> some View {
        self.modifier(ScrollSwipeModifier(overlayId: overlayId, isTopPosition: isTopPosition))
    }
    
    func threeFingerClickToDismiss(overlayId: String) -> some View {
        self.modifier(ThreeFingerClickDismissModifier(overlayId: overlayId))
    }
    
    // Alias for backward compatibility
    func twoFingerClickToDismiss(overlayId: String) -> some View {
        self.threeFingerClickToDismiss(overlayId: overlayId)
    }
}

typealias TwoFingerClickDismissModifier = ThreeFingerClickDismissModifier

struct ThreeFingerClickDismissModifier: ViewModifier {
    let overlayId: String
    
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("enableThreeFingerClickToDismiss") private var enableThreeFingerClickToDismiss = true
    
    @State private var globalMonitor: Any?
    @State private var localMonitor: Any?
    @State private var isDismissing = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                isDismissing = false
                setupMonitors()
            }
            .onDisappear {
                removeMonitors()
            }
    }
    
    private func setupMonitors() {
        removeMonitors()
        
        let handleDismiss: (NSEvent) -> Bool = { event in
            let enable = UserDefaults.standard.object(forKey: "enableThreeFingerClickToDismiss") as? Bool ?? (UserDefaults.standard.object(forKey: "enableTwoFingerClickToDismiss") as? Bool ?? true)
            guard enable else { return false }
            
            let isHit = VisorProWindowManager.shared.isOverlayHit(by: event, overlayId: overlayId)
            if isHit && !isDismissing {
                isDismissing = true
                Task { @MainActor in
                    mediaKeyManager.forceHide(overlayId: overlayId)
                }
                return true
            }
            return false
        }
        
        // Catches secondary / three-finger clicks when VisorPro is in background
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.rightMouseDown, .otherMouseDown]) { event in
            _ = handleDismiss(event)
        }
        
        // Catches secondary / three-finger clicks when VisorPro is active and consumes them
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .otherMouseDown, .rightMouseUp, .otherMouseUp]) { event in
            if event.type == .rightMouseDown || event.type == .otherMouseDown {
                if handleDismiss(event) {
                    return nil
                }
            } else if event.type == .rightMouseUp || event.type == .otherMouseUp {
                if isDismissing {
                    isDismissing = false
                    return nil
                }
            }
            return event
        }
    }
    
    private func removeMonitors() {
        if let g = globalMonitor {
            NSEvent.removeMonitor(g)
            globalMonitor = nil
        }
        if let l = localMonitor {
            NSEvent.removeMonitor(l)
            localMonitor = nil
        }
    }
}
import SwiftUI
import AppKit

class PassThroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let view = super.hitTest(point)
        // If the view returned is exactly the hosting view (empty space), pass the click through.
        return view === self ? nil : view
    }
}
