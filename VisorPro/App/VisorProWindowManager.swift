import Foundation
import AppKit
import SwiftUI
import Combine

@MainActor
class VisorProWindowManager: ObservableObject {
    static let shared = VisorProWindowManager()
    
    private var windows: [String: NSPanel] = [:]
    private var targetOrigins: [String: NSPoint] = [:]
    private var shownPanels: Set<String> = []
    private var exitingPanels: Set<String> = []
    private var cancellables = Set<AnyCancellable>()
    private var overlayTimestamps: [String: Date] = [:]
    
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

    private func getSlotX(index: Int, totalSlots: Int, in size: CGSize) -> CGFloat {
        if totalSlots <= 1 {
            return size.width / 2
        }
        let margin: CGFloat = 40
        let averageWidth: CGFloat = 260
        let availableWidth = size.width - 2 * margin
        let spacing = (availableWidth - CGFloat(totalSlots) * averageWidth) / CGFloat(totalSlots - 1)
        
        return margin + (averageWidth / 2) + CGFloat(index) * (averageWidth + spacing)
    }

    private func computeLayerPositions(overlays: [ActiveOverlay], limit: Int, size: CGSize) -> [String: CGFloat] {
        let lefts = overlays.filter { $0.position.hasSuffix("_left") }
        let rights = overlays.filter { $0.position.hasSuffix("_right") }
        let centers = overlays.filter { !$0.position.hasSuffix("_left") && !$0.position.hasSuffix("_right") }
        
        let w: CGFloat = 260
        let s: CGFloat = 24
        let marginVal = UserDefaults.standard.object(forKey: "overlayMargin"); let m: CGFloat = marginVal != nil ? CGFloat(marginVal as! Double) : 30.0
        
        let countLeft = lefts.count
        let countCenter = centers.count
        let countRight = rights.count
        
        let leftEnd = countLeft > 0 ? (m + CGFloat(countLeft) * w + CGFloat(countLeft - 1) * s) : 0
        let rightStart = countRight > 0 ? (size.width - m - (CGFloat(countRight) * w + CGFloat(countRight - 1) * s)) : size.width
        
        var hasCollision = false
        if countLeft > 0 && countRight > 0 && countCenter == 0 {
            if leftEnd + s > rightStart { hasCollision = true }
        }
        if countCenter > 0 {
            let totalCenterWidth = CGFloat(countCenter) * w + CGFloat(max(0, countCenter - 1)) * s
            let centerStart = (size.width - totalCenterWidth) / 2
            let centerEnd = centerStart + totalCenterWidth
            
            if countLeft > 0 && (leftEnd + s > centerStart) { hasCollision = true }
            if countRight > 0 && (centerEnd + s > rightStart) { hasCollision = true }
        }
        
        var result: [String: CGFloat] = [:]
        
        if !hasCollision {
            for (index, overlay) in lefts.enumerated() {
                let startX = m + (w / 2)
                result[overlay.id] = startX + CGFloat(index) * (w + s)
            }
            for (index, overlay) in rights.enumerated() {
                let startX = size.width - m - (w / 2)
                result[overlay.id] = startX - CGFloat(index) * (w + s)
            }
            let totalCenterWidth = CGFloat(countCenter) * w + CGFloat(max(0, countCenter - 1)) * s
            let startX = (size.width - totalCenterWidth) / 2 + (w / 2)
            for (index, overlay) in centers.enumerated() {
                result[overlay.id] = startX + CGFloat(index) * (w + s)
            }
        } else {
            let slotMap = assignSlots(overlays: overlays, limit: limit)
            for (id, slotIndex) in slotMap {
                result[id] = getSlotX(index: slotIndex, totalSlots: limit, in: size)
            }
        }
        
        return result
    }

    
    private init() {
        MediaKeyManager.shared.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateWindows()
            }
        }.store(in: &cancellables)
        
        Timer.publish(every: 0.1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            self?.updateWindows()
        }.store(in: &cancellables)
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
        let manager = MediaKeyManager.shared
        var active: [ActiveOverlay] = []
        
        let volumeOverlayPosition = MediaKeyManager.shared.getOverlayPosition(for: "volumeOverlayPosition")
        let batteryOverlayPosition = MediaKeyManager.shared.getOverlayPosition(for: "batteryOverlayPosition")
        let brightnessOverlayPosition = MediaKeyManager.shared.getOverlayPosition(for: "brightnessOverlayPosition")
        let keyboardBrightnessOverlayPosition = MediaKeyManager.shared.getOverlayPosition(for: "keyboardBrightnessOverlayPosition")
        let copyOverlayPosition = MediaKeyManager.shared.getOverlayPosition(for: "copyOverlayPosition")
        let capsLockOverlayPosition = MediaKeyManager.shared.getOverlayPosition(for: "capsLockOverlayPosition")
        
        let showBattery = manager.showChargingStatus || manager.showLowBatteryWarning || manager.showUnpluggedStatus
        
        if manager.showVolumeIndicator { active.append(ActiveOverlay(id: "volume", type: .volume, position: volumeOverlayPosition, notification: nil)) }
        if manager.showBrightnessIndicator { active.append(ActiveOverlay(id: "brightness", type: .brightness, position: brightnessOverlayPosition, notification: nil)) }
        if manager.showKeyboardBrightnessIndicator { active.append(ActiveOverlay(id: "keyboardBrightness", type: .keyboardBrightness, position: keyboardBrightnessOverlayPosition, notification: nil)) }
        if showBattery { 
            let batId = (manager.showLowBatteryWarning && !manager.isPluggedIn) ? "battery_warning" : "battery_charging"
            active.append(ActiveOverlay(id: batId, type: .battery, position: batteryOverlayPosition, notification: nil)) 
        }
        if manager.showCopyIndicator { active.append(ActiveOverlay(id: "copy", type: .copy, position: copyOverlayPosition, notification: nil)) }
        if manager.showCapsLockIndicator { active.append(ActiveOverlay(id: "capsLock", type: .capsLock, position: capsLockOverlayPosition, notification: nil)) }
        
        let btPos = MediaKeyManager.shared.getOverlayPosition(for: "bluetoothOverlayPosition")
        for notif in manager.activeBluetoothNotifications {
            active.append(ActiveOverlay(id: "bluetooth_\(notif.id)", type: .bluetooth, position: btPos, notification: notif))
        }
        
        let langPos = MediaKeyManager.shared.getOverlayPosition(for: "languageOverlayPosition")
        if manager.showLanguageIndicator { active.append(ActiveOverlay(id: "language", type: .language, position: langPos, notification: nil)) }
        
        let mediaPos = MediaKeyManager.shared.getOverlayPosition(for: "mediaOverlayPosition")
        if manager.showMediaIndicator { active.append(ActiveOverlay(id: "media", type: .media, position: mediaPos, notification: nil)) }
        
        let themePos = MediaKeyManager.shared.getOverlayPosition(for: "themeOverlayPosition")
        if manager.showThemeIndicator { active.append(ActiveOverlay(id: "theme", type: .theme, position: themePos, notification: nil)) }
        
        let micPos = MediaKeyManager.shared.getOverlayPosition(for: "micOverlayPosition")
        if manager.showMicIndicator { active.append(ActiveOverlay(id: "mic", type: .mic, position: micPos, notification: nil)) }
        
        let camPos = MediaKeyManager.shared.getOverlayPosition(for: "cameraOverlayPosition")
        if manager.showCameraIndicator { active.append(ActiveOverlay(id: "camera", type: .camera, position: camPos, notification: nil)) }
        
        let locPos = MediaKeyManager.shared.getOverlayPosition(for: "locationOverlayPosition")
        if manager.showLocationIndicator { active.append(ActiveOverlay(id: "location", type: .location, position: locPos, notification: nil)) }
        
        let wifiPos = MediaKeyManager.shared.getOverlayPosition(for: "wifiOverlayPosition")
        if manager.showWiFiIndicator { active.append(ActiveOverlay(id: "wifi", type: .wifi, position: wifiPos, notification: nil)) }
        
        let periPos = MediaKeyManager.shared.getOverlayPosition(for: "peripheralOverlayPosition")
        for notif in manager.activePeripheralNotifications {
            active.append(ActiveOverlay(id: "peripheral_\(notif.id)", type: .peripheral, position: periPos, notification: notif))
        }
        
        let displayPos = MediaKeyManager.shared.getOverlayPosition(for: "displayOverlayPosition")
        for notif in manager.activeDisplayNotifications {
            active.append(ActiveOverlay(id: "display_\(notif.id)", type: .display, position: displayPos, notification: notif))
        }
        
        let fanPos = MediaKeyManager.shared.getOverlayPosition(for: "fanOverlayPosition")
        if manager.showFanIndicator { active.append(ActiveOverlay(id: "fan", type: .fan, position: fanPos, notification: nil)) }
        
        let ramPos = MediaKeyManager.shared.getOverlayPosition(for: "ramOverlayPosition")
        if manager.showRamIndicator { active.append(ActiveOverlay(id: "ram", type: .ram, position: ramPos, notification: nil)) }
        let cpuPos = MediaKeyManager.shared.getOverlayPosition(for: "cpuOverlayPosition")
        if manager.showCpuIndicator { active.append(ActiveOverlay(id: "cpu", type: .cpu, position: cpuPos, notification: nil)) }
        
        let accBatPos = MediaKeyManager.shared.getOverlayPosition(for: "batteryOverlayPosition")
        if manager.showAccessoryBatteryIndicator {
            active.append(ActiveOverlay(id: "accessoryBattery", type: .accessoryBattery, position: accBatPos, notification: nil))
        }
        
        let limit = max(1, manager.maxSimultaneousNotifications)
        
        let now = Date()
        for overlay in active {
            if let triggerTime = manager.overlayTriggerTimes[overlay.id] {
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
            
        var finalActive: [ActiveOverlay] = []
        for overlay in active {
            if topToKeep.contains(overlay.id) || bottomToKeep.contains(overlay.id) {
                finalActive.append(overlay)
            }
        }
        
        return finalActive
    }
    
    func updateWindows() {
        let active = allActiveOverlays
        var uniqueScreens: [NSScreen] = []
        var seenOrigins = Set<String>()
        for screen in NSScreen.screens {
            let originKey = "\(Int(screen.frame.origin.x)),\(Int(screen.frame.origin.y))"
            if !seenOrigins.contains(originKey) {
                seenOrigins.insert(originKey)
                uniqueScreens.append(screen)
            }
        }
        
        if MediaKeyManager.shared.forceSingleScreenForDisplayTransition && !uniqueScreens.isEmpty {
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
            finalScreens = uniqueScreens
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
                    window.alphaValue = 0
                    window.close()
                    windows.removeValue(forKey: id)
                    targetOrigins.removeValue(forKey: id)
                    shownPanels.remove(id)
                } else {
                    exitingPanels.insert(id)
                    let currentSwipeOffset = MediaKeyManager.shared.swipeOffsets[overlayId] ?? 0.0
                    
                    if abs(currentSwipeOffset) > 30 {
                        NSAnimationContext.runAnimationGroup({ ctx in
                            ctx.duration = 0.1
                            window.animator().alphaValue = 0.0
                        }, completionHandler: {
                            Task { @MainActor in
                                window.close()
                                MediaKeyManager.shared.swipeOffsets[overlayId] = 0
                                self.windows.removeValue(forKey: id)
                                self.targetOrigins.removeValue(forKey: id)
                                self.shownPanels.remove(id)
                                self.exitingPanels.remove(id)
                            }
                        })
                    } else {
                        let isTop = window.frame.origin.y > (NSScreen.screens.first?.frame.height ?? 800) / 2
                        let offsetAmount: CGFloat = isTop ? 20 : -20 
                        
                        NSAnimationContext.runAnimationGroup({ ctx in
                            ctx.duration = 0.2
                            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                            var finalFrame = window.frame
                            finalFrame.origin.y += offsetAmount
                            window.animator().setFrame(finalFrame, display: false)
                            window.animator().alphaValue = 0.0
                        }, completionHandler: {
                            Task { @MainActor in
                                if self.exitingPanels.contains(id) {
                                    window.close()
                                    self.windows.removeValue(forKey: id)
                                    self.targetOrigins.removeValue(forKey: id)
                                    self.shownPanels.remove(id)
                                    self.exitingPanels.remove(id)
                                }
                            }
                        })
                    }
                }
            } else {
                if exitingPanels.contains(id) {
                    exitingPanels.remove(id)
                    rescuedPanels.insert(id)
                }
            }
        }
        
        let limit = max(1, MediaKeyManager.shared.maxSimultaneousNotifications)
        let topOverlays = active.filter { $0.position.hasPrefix("top") }
        let bottomOverlays = active.filter { $0.position.hasPrefix("bottom") }
        
        for (screenIndex, screen) in finalScreens.enumerated() {
            let screenSize = screen.visibleFrame.size
            let screenOrigin = screen.visibleFrame.origin
            
            let topPositions = computeLayerPositions(overlays: topOverlays, limit: limit, size: screenSize)
            let bottomPositions = computeLayerPositions(overlays: bottomOverlays, limit: limit, size: screenSize)
            let allPositions = topPositions.merging(bottomPositions) { (current, _) in current }
            
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
                
                let baseH: CGFloat
                if overlay.type == .media { baseH = 72 }
                else if overlay.type == .battery {
                    let manager = MediaKeyManager.shared
                    let isFullyCharged = manager.currentBatteryPercentage == 100 || manager.isEffectivelyFullyCharged
                    baseH = isFullyCharged ? 56 : 72
                } else { baseH = 56 }
                
                let originY: CGFloat
                let downwardShift: CGFloat = 4.0 // Slight correction to lower the overlays
                if overlay.position.hasPrefix("top") {
                    let topEdge = yCenter + (baseH / 2)
                    originY = topEdge - currentHeight - downwardShift
                } else if overlay.position.hasPrefix("bottom") {
                    let bottomEdge = yCenter - (baseH / 2)
                    originY = bottomEdge - downwardShift
                } else {
                    originY = yCenter - (currentHeight / 2) - downwardShift
                }
                
                let swipeOffset = MediaKeyManager.shared.swipeOffsets[overlay.id] ?? 0.0
                let originY_withOffset = originY - swipeOffset
                
                let targetOrigin = NSPoint(x: originX, y: originY_withOffset)
                
                if let last = targetOrigins[windowId], abs(last.y - originY) > 2000 {
                    windows[windowId]?.close()
                    windows.removeValue(forKey: windowId)
                    targetOrigins.removeValue(forKey: windowId)
                    shownPanels.remove(windowId)
                }
                
                let lastTarget = targetOrigins[windowId]
                let isFirstShow = !shownPanels.contains(windowId)
                
                if isFirstShow {
                    shownPanels.insert(windowId)
                    targetOrigins[windowId] = targetOrigin
                    
                    let isTop = targetOrigin.y > (screenSize.height / 2)
                    let offsetAmount: CGFloat = isTop ? 20 : -20
                    let startOrigin = NSPoint(x: targetOrigin.x, y: targetOrigin.y + offsetAmount)
                    
                    panel.alphaValue = 0.0
                    panel.setFrame(NSRect(origin: startOrigin, size: CGSize(width: currentWidth, height: currentHeight)), display: true)
                    panel.orderFront(nil)
                    
                    panel.contentView?.layoutSubtreeIfNeeded()
                    panel.displayIfNeeded()
                    
                    NSAnimationContext.runAnimationGroup({ ctx in
                        ctx.duration = 0.2
                        ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                        panel.animator().setFrame(NSRect(origin: targetOrigin, size: CGSize(width: currentWidth, height: currentHeight)), display: false)
                        panel.animator().alphaValue = 1.0 - (abs(swipeOffset) / 60.0)
                    }, completionHandler: {
                        // Usunięto manualne isWindowUnderMouse. 
                        // TrackingNSView (onHoverExact) automatycznie sprawdzi pozycję myszy po animacji.
                    })
                } else if !MediaKeyManager.shared.isDisplayTransitioning {
                    let isRescued = rescuedPanels.contains(windowId)
                    if lastTarget == nil || abs(lastTarget!.x - targetOrigin.x) > 0.5 || abs(lastTarget!.y - targetOrigin.y) > 0.5 || isRescued {
                        targetOrigins[windowId] = targetOrigin
                        let isDragging = MediaKeyManager.shared.activeSwipeIds.contains(overlay.id)
                        
                        if isDragging {
                            panel.setFrame(NSRect(origin: targetOrigin, size: CGSize(width: currentWidth, height: currentHeight)), display: false)
                            panel.alphaValue = 1.0 - (abs(swipeOffset) / 60.0)
                        } else {
                            NSAnimationContext.runAnimationGroup { ctx in
                                ctx.duration = 0.2
                                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
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
        let w: CGFloat = (overlay.type == .capsLock || overlay.type == .theme) ? 230 : 260
        let h: CGFloat
        if overlay.type == .media {
            h = 72
        } else if overlay.type == .battery {
            let manager = MediaKeyManager.shared
            let isFullyCharged = manager.currentBatteryPercentage == 100 || manager.isEffectivelyFullyCharged
            h = isFullyCharged ? 56 : 72
        } else {
            h = 56
        }
        
        let panel = VisorProOverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: w + 40, height: h + 60),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
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
        
        let view = SingleOverlayContainer(overlay: overlay).environmentObject(MediaKeyManager.shared)
        panel.contentView = NSHostingView(rootView: view)
        
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        
        return panel
    }
    
    private func yPos(for position: String, in size: CGSize) -> CGFloat {
        let marginVal = UserDefaults.standard.object(forKey: "overlayMargin"); let margin = marginVal != nil ? CGFloat(marginVal as! Double) : 30.0
        let bottomPadding: CGFloat = margin
        let topPadding: CGFloat = margin
        let pillHeight: CGFloat = 56
        if position.hasPrefix("top") { return size.height - topPadding - (pillHeight / 2) } 
        if position == "center" { return size.height / 2 }
        return bottomPadding + (pillHeight / 2)
    }

    func isWindowUnderMouse(for overlayId: String) -> Bool {
        let mouseLoc = NSEvent.mouseLocation
        
        var hitPanels: [(key: String, panel: NSWindow)] = []
        for (key, panel) in windows {
            // Inset by container padding (.top 10, .bottom 15, .horizontal 12) so hit area matches the visible overlay
            let insetFrame = panel.frame.insetBy(dx: 12, dy: 0)
            let visibleFrame = NSRect(
                x: insetFrame.origin.x,
                y: insetFrame.origin.y + 15,
                width: insetFrame.width,
                height: insetFrame.height - 25  // 10 top + 15 bottom
            )
            if visibleFrame.contains(mouseLoc) {
                hitPanels.append((key, panel))
            }
        }
        
        if hitPanels.isEmpty { return false }
        
        // NSApp.orderedWindows is ordered from front to back
        for window in NSApp.orderedWindows {
            if let match = hitPanels.first(where: { $0.panel === window }) {
                return match.key.hasPrefix(overlayId)
            }
        }
        
        return false
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
    private var stableMidX: CGFloat?
    
    override var canBecomeKey: Bool { return false }
    override var canBecomeMain: Bool { return false }
    
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
    
    private func adjustFrame(_ frameRect: NSRect) -> NSRect {
        var newFrame = frameRect
        let oldFrame = self.frame
        
        let isResize = oldFrame.size.height > 0 && abs(oldFrame.size.height - newFrame.size.height) > 0.1
        let isWidthResize = oldFrame.size.width > 0 && abs(oldFrame.size.width - newFrame.size.width) > 0.1
        
        if isWidthResize {
            let centerX = stableMidX ?? oldFrame.midX
            newFrame.origin.x = centerX - (newFrame.width / 2)
            stableMidX = centerX
        } else {
            stableMidX = newFrame.midX
        }
        
        if isResize {
            switch anchorMode {
            case .bottom:
                let minY = stableMinY ?? oldFrame.minY
                newFrame.origin.y = minY
                stableMinY = minY
            case .top:
                let maxY = stableMaxY ?? oldFrame.maxY
                newFrame.origin.y = maxY - newFrame.height
                stableMaxY = maxY
            case .center:
                let midY = stableMidY ?? oldFrame.midY
                newFrame.origin.y = midY - (newFrame.height / 2)
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




struct SingleOverlayContainer: View {
    let overlay: VisorProWindowManager.ActiveOverlay
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    
    private var currentOverlay: VisorProWindowManager.ActiveOverlay? {
        VisorProWindowManager.shared.allActiveOverlays.first(where: { $0.id == overlay.id })
    }
    private var isOverlayActive: Bool {
        currentOverlay != nil
    }
    
    private var placeholderWidth: CGFloat {
        (overlay.type == .capsLock || overlay.type == .theme) ? 230 : 260
    }
    
    private var placeholderHeight: CGFloat {
        if overlay.type == .media {
            return 72
        } else if overlay.type == .battery {
            let isFullyCharged = mediaKeyManager.currentBatteryPercentage == 100 || mediaKeyManager.isEffectivelyFullyCharged
            return isFullyCharged ? 56 : 72
        } else {
            return 56
        }
    }
    
    var body: some View {
        ZStack {
            if isOverlayActive, let current = currentOverlay {
                overlayView(for: current)
                    .applyTheme(mediaKeyManager.overlayTheme)
                    .swipeToDismiss(overlayId: current.id, isTopPosition: current.position.hasPrefix("top"))
            } else {
                Color.clear.frame(width: placeholderWidth, height: placeholderHeight)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 15)
        .padding(.horizontal, 12)
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
        case .language: LanguageOverlayView()
        case .media: MediaOverlayView()
        case .theme: ThemeOverlayView()
        case .mic: MicOverlayView()
        case .camera: CameraOverlayView()
        case .location: LocationOverlayView()
        case .wifi: WiFiOverlayView()
        case .peripheral: PeripheralOverlayView(notification: overlay.notification)
        case .display: DisplayOverlayView(notification: overlay.notification)
        case .fan: FanOverlayView()
        case .ram: RamOverlayView()
        case .accessoryBattery: AccessoryBatteryOverlayView()
        case .cpu: CpuTemperatureOverlayView(isPreview: false)
        }
    }
}

struct ScrollSwipeModifier: ViewModifier {
    let overlayId: String
    let isTopPosition: Bool
    
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("enableSwipeToDismiss") private var enableSwipeToDismiss = true
    
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
                mediaKeyManager.swipeOffsets[overlayId] = 0
                setupMonitors()
            }
            .onDisappear {
                removeMonitors()
                mediaKeyManager.swipeOffsets[overlayId] = 0
            }
    }
    
    private func handleScroll(event: NSEvent) {
        guard enableSwipeToDismiss else { return }
        guard !isDismissing else { return }
        
        var isHovered = mediaKeyManager.actualHoveredTypes.contains(overlayId) ||
                        (overlayId.hasPrefix("ram") && mediaKeyManager.actualHoveredTypes.contains("ram")) ||
                        (overlayId.hasPrefix("fan") && mediaKeyManager.actualHoveredTypes.contains("fan")) ||
                        (overlayId.hasPrefix("bluetooth") && mediaKeyManager.actualHoveredTypes.contains("bluetooth")) ||
                        (overlayId.hasPrefix("peripheral") && mediaKeyManager.actualHoveredTypes.contains("peripheral")) ||
                        (overlayId.hasPrefix("display") && mediaKeyManager.actualHoveredTypes.contains("display"))
        
        // Polegamy wyłącznie na precyzyjnym systemie onHoverExact z UniversalOverlayView
        // który śledzi idealnie krawędzie interfejsu (globalHoveredTypes), ignorując ukryte pole NSWindow.
        var isCurrentlySwiping = mediaKeyManager.activeSwipeIds.contains(overlayId)
        
        let phase = event.phase
        let momentum = event.momentumPhase
        
        if phase == .began && !isHovered {
            mediaKeyManager.activeSwipeIds.remove(overlayId)
            isCurrentlySwiping = false
        }
        

        guard isHovered || isCurrentlySwiping else { return }
        
        let rawDelta = event.scrollingDeltaY
        let deltaY = event.isDirectionInvertedFromDevice ? -rawDelta : rawDelta
        
        let isEnding = phase == .ended || phase == .cancelled || momentum == .ended || momentum == .cancelled
        if isEnding {
            mediaKeyManager.activeSwipeIds.remove(overlayId)
            debounceTimer?.invalidate()
            guard !isDismissing else { return }
            dragOffset = 0
            totalScrollDelta = 0
            mediaKeyManager.swipeOffsets[overlayId] = 0
            mediaKeyManager.keepAlive(for: overlayId, isHovering: isHovered)
            return
        }
        
        guard abs(deltaY) > 0.5 else { return }
        
        totalScrollDelta += deltaY
        
        if abs(totalScrollDelta) > 10 {
            mediaKeyManager.activeSwipeIds.insert(overlayId)
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
            mediaKeyManager.activeSwipeIds.remove(overlayId)
        }
        
        // Always and consistently assign the current delta (which grows from the finger or from inertial momentum).
        mediaKeyManager.swipeOffsets[overlayId] = dragOffset
        
        if !isDismissing {
            if phase.rawValue == 0 && momentum.rawValue == 0 {
                debounceTimer?.invalidate()
                debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                    guard !isDismissing else { return }
                    mediaKeyManager.activeSwipeIds.remove(overlayId)
                    dragOffset = 0
                    totalScrollDelta = 0
                    mediaKeyManager.swipeOffsets[overlayId] = 0
                }
            }
        }
    }
    
    private func setupMonitors() {
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
}
