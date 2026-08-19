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
    private var cancellables = Set<AnyCancellable>()
    private var overlayTimestamps: [String: Date] = [:]
    
    private func calculateDynamicPositions(overlays: [ActiveOverlay], in size: CGSize) -> [String: CGFloat] {
        var posMap: [String: CGFloat] = [:]
        
        let lefts = overlays.filter { $0.position.hasSuffix("_left") }
        let rights = overlays.filter { $0.position.hasSuffix("_right") }
        let centers = overlays.filter { !$0.position.hasSuffix("_left") && !$0.position.hasSuffix("_right") }
        
        let margin: CGFloat = 40
        let averageWidth: CGFloat = 260
        let spacing: CGFloat = 24
        
        var safeMinX: CGFloat = 0
        var safeMaxX: CGFloat = size.width
        
        if !lefts.isEmpty {
            let leftsTotalW = CGFloat(lefts.count) * averageWidth + CGFloat(lefts.count - 1) * spacing
            safeMinX = margin + leftsTotalW + spacing
            
            for (i, overlay) in lefts.enumerated() {
                posMap[overlay.id] = margin + (averageWidth / 2) + CGFloat(i) * (averageWidth + spacing)
            }
        }
        
        if !rights.isEmpty {
            let rightsTotalW = CGFloat(rights.count) * averageWidth + CGFloat(rights.count - 1) * spacing
            safeMaxX = size.width - margin - rightsTotalW - spacing
            
            for (i, overlay) in rights.enumerated() {
                posMap[overlay.id] = size.width - margin - (averageWidth / 2) - CGFloat(i) * (averageWidth + spacing)
            }
        }
        
        if !centers.isEmpty {
            let centerTotalW = CGFloat(centers.count) * averageWidth + CGFloat(centers.count - 1) * spacing
            let availableWidth = max(0, safeMaxX - safeMinX)
            let startX = safeMinX + (availableWidth - centerTotalW) / 2 + (averageWidth / 2)
            
            for (i, overlay) in centers.enumerated() {
                posMap[overlay.id] = startX + CGFloat(i) * (averageWidth + spacing)
            }
        }
        
        return posMap
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
        
        let volumeOverlayPosition = UserDefaults.standard.string(forKey: "volumeOverlayPosition") ?? "bottom"
        let batteryOverlayPosition = UserDefaults.standard.string(forKey: "batteryOverlayPosition") ?? "top"
        let brightnessOverlayPosition = UserDefaults.standard.string(forKey: "brightnessOverlayPosition") ?? "top"
        let keyboardBrightnessOverlayPosition = UserDefaults.standard.string(forKey: "keyboardBrightnessOverlayPosition") ?? "top"
        let copyOverlayPosition = UserDefaults.standard.string(forKey: "copyOverlayPosition") ?? "bottom"
        let capsLockOverlayPosition = UserDefaults.standard.string(forKey: "capsLockOverlayPosition") ?? "bottom"
        
        let showBattery = manager.showChargingStatus || manager.showLowBatteryWarning
        
        if manager.showVolumeIndicator { active.append(ActiveOverlay(id: "volume", type: .volume, position: volumeOverlayPosition, notification: nil)) }
        if manager.showBrightnessIndicator { active.append(ActiveOverlay(id: "brightness", type: .brightness, position: brightnessOverlayPosition, notification: nil)) }
        if manager.showKeyboardBrightnessIndicator { active.append(ActiveOverlay(id: "keyboardBrightness", type: .keyboardBrightness, position: keyboardBrightnessOverlayPosition, notification: nil)) }
        if showBattery { 
            let batId = (manager.showLowBatteryWarning && !manager.isPluggedIn) ? "battery_warning" : "battery_charging"
            active.append(ActiveOverlay(id: batId, type: .battery, position: batteryOverlayPosition, notification: nil)) 
        }
        if manager.showCopyIndicator { active.append(ActiveOverlay(id: "copy", type: .copy, position: copyOverlayPosition, notification: nil)) }
        if manager.showCapsLockIndicator { active.append(ActiveOverlay(id: "capsLock", type: .capsLock, position: capsLockOverlayPosition, notification: nil)) }
        
        let btPos = UserDefaults.standard.string(forKey: "bluetoothOverlayPosition") ?? "bottom"
        for notif in manager.activeBluetoothNotifications {
            active.append(ActiveOverlay(id: "bluetooth_\(notif.id)", type: .bluetooth, position: btPos, notification: notif))
        }
        
        let langPos = UserDefaults.standard.string(forKey: "languageOverlayPosition") ?? "bottom"
        if manager.showLanguageIndicator { active.append(ActiveOverlay(id: "language", type: .language, position: langPos, notification: nil)) }
        
        let mediaPos = UserDefaults.standard.string(forKey: "mediaOverlayPosition") ?? "bottom"
        if manager.showMediaIndicator { active.append(ActiveOverlay(id: "media", type: .media, position: mediaPos, notification: nil)) }
        
        let themePos = UserDefaults.standard.string(forKey: "themeOverlayPosition") ?? "bottom"
        if manager.showThemeIndicator { active.append(ActiveOverlay(id: "theme", type: .theme, position: themePos, notification: nil)) }
        
        let micPos = UserDefaults.standard.string(forKey: "micOverlayPosition") ?? "top"
        if manager.showMicIndicator { active.append(ActiveOverlay(id: "mic", type: .mic, position: micPos, notification: nil)) }
        
        let camPos = UserDefaults.standard.string(forKey: "cameraOverlayPosition") ?? "top"
        if manager.showCameraIndicator { active.append(ActiveOverlay(id: "camera", type: .camera, position: camPos, notification: nil)) }
        
        let locPos = UserDefaults.standard.string(forKey: "locationOverlayPosition") ?? "top"
        if manager.showLocationIndicator { active.append(ActiveOverlay(id: "location", type: .location, position: locPos, notification: nil)) }
        
        let wifiPos = UserDefaults.standard.string(forKey: "wifiOverlayPosition") ?? "bottom"
        if manager.showWiFiIndicator { active.append(ActiveOverlay(id: "wifi", type: .wifi, position: wifiPos, notification: nil)) }
        
        let periPos = UserDefaults.standard.string(forKey: "peripheralOverlayPosition") ?? "bottom"
        for notif in manager.activePeripheralNotifications {
            active.append(ActiveOverlay(id: "peripheral_\(notif.id)", type: .peripheral, position: periPos, notification: notif))
        }
        
        let displayPos = UserDefaults.standard.string(forKey: "displayOverlayPosition") ?? "bottom"
        for notif in manager.activeDisplayNotifications {
            active.append(ActiveOverlay(id: "display_\(notif.id)", type: .display, position: displayPos, notification: notif))
        }
        
        let fanPos = UserDefaults.standard.string(forKey: "fanOverlayPosition") ?? "bottom"
        if manager.showFanIndicator { active.append(ActiveOverlay(id: "fan_\(manager.fanEventId)", type: .fan, position: fanPos, notification: nil)) }
        
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
        
        let topOverlays = active.filter { $0.position.hasPrefix("top") }
            .sorted { (self.overlayTimestamps[$0.id] ?? now) > (self.overlayTimestamps[$1.id] ?? now) }
            .prefix(limit)
            
        let bottomOverlays = active.filter { $0.position.hasPrefix("bottom") }
            .sorted { (self.overlayTimestamps[$0.id] ?? now) > (self.overlayTimestamps[$1.id] ?? now) }
            .prefix(limit)
            
        var finalActive: [ActiveOverlay] = []
        finalActive.append(contentsOf: topOverlays)
        finalActive.append(contentsOf: bottomOverlays)
        
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
        
        for (id, window) in windows {
            if !targetWindowIds.contains(id) {
                let overlayId = String(id.split(separator: "_screen_").first ?? "")
                let isOverlayStillActive = active.contains { $0.id == overlayId }
                
                if isOverlayStillActive {
                    // Screen vanished. Hide immediately so macOS doesn't snap the orphaned window to the main display.
                    window.orderOut(nil)
                    window.alphaValue = 0
                    window.close()
                } else {
                    // Normal overlay dismissal timeout. Let SwiftUI animate out.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        window.close()
                    }
                }
                windows.removeValue(forKey: id)
                targetOrigins.removeValue(forKey: id)
                shownPanels.remove(id)
            }
        }
        
        let topOverlays = active.filter { $0.position.hasPrefix("top") }
        let bottomOverlays = active.filter { $0.position.hasPrefix("bottom") }
        
        for (screenIndex, screen) in finalScreens.enumerated() {
            let screenSize = screen.visibleFrame.size
            let screenOrigin = screen.visibleFrame.origin
            
            let topPositions = calculateDynamicPositions(overlays: topOverlays, in: screenSize)
            let bottomPositions = calculateDynamicPositions(overlays: bottomOverlays, in: screenSize)
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
                
                let x = (allPositions[overlay.id] ?? (screenSize.width / 2)) + screenOrigin.x
                let yCenter = yPos(for: overlay.position, in: screenSize) + screenOrigin.y
                
                let currentWidth = panel.frame.width
                let currentHeight = panel.frame.height
                
                let originX = x - (currentWidth / 2)
                let originY: CGFloat
                
                let baseH: CGFloat = (overlay.type == .media) ? 72 : 56
                let offsetFromBottom = 15 + (baseH / 2)
                let offsetFromTop = 10 + (baseH / 2)
                
                if overlay.position.hasPrefix("top") {
                    originY = yCenter + offsetFromTop - currentHeight
                } else if overlay.position.hasPrefix("bottom") {
                    originY = yCenter - offsetFromBottom
                } else {
                    originY = yCenter - (currentHeight / 2)
                }
                
                let targetOrigin = NSPoint(x: originX, y: originY)
                
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
                    panel.alphaValue = 1
                    panel.setFrame(NSRect(origin: targetOrigin, size: CGSize(width: currentWidth, height: currentHeight)), display: true)
                    panel.orderFront(nil)
                } else if !MediaKeyManager.shared.isDisplayTransitioning {
                    if lastTarget == nil || abs(lastTarget!.x - targetOrigin.x) > 0.5 || abs(lastTarget!.y - targetOrigin.y) > 0.5 {
                        targetOrigins[windowId] = targetOrigin
                        NSAnimationContext.runAnimationGroup { ctx in
                            ctx.duration = 0.35
                            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                            panel.animator().setFrame(NSRect(origin: targetOrigin, size: CGSize(width: currentWidth, height: currentHeight)), display: true)
                        }
                    }
                }
            }
        }
    }
    
    private func createPanel(for overlay: ActiveOverlay) -> NSPanel {
        let w: CGFloat = (overlay.type == .capsLock || overlay.type == .theme) ? 230 : 260
        let h: CGFloat = (overlay.type == .media) ? 72 : 56
        let panel = VisorProOverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: w + 24, height: h + 25),
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
        let bottomPadding: CGFloat = 40
        let topPadding: CGFloat = 10
        let pillHeight: CGFloat = 56
        if position.hasPrefix("top") { return size.height - topPadding - (pillHeight / 2) } 
        if position == "center" { return size.height / 2 }
        return bottomPadding + (pillHeight / 2)
    }


}


enum WindowAnchorMode {
    case top
    case bottom
    case center
}

class VisorProOverlayPanel: NSPanel {
    var anchorMode: WindowAnchorMode = .center
    
    override var canBecomeKey: Bool { return false }
    override var canBecomeMain: Bool { return false }
    
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
    
    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        var newFrame = frameRect
        let oldFrame = self.frame
        
        if oldFrame.size.height > 0 && oldFrame.size.height != newFrame.size.height {
            switch anchorMode {
            case .bottom:
                newFrame.origin.y = oldFrame.minY
            case .top:
                newFrame.origin.y = oldFrame.maxY - newFrame.height
            case .center:
                let oldCenterY = oldFrame.midY
                newFrame.origin.y = oldCenterY - (newFrame.height / 2)
            }
        }
        
        super.setFrame(newFrame, display: flag)
    }
    
    override func setFrame(_ frameRect: NSRect, display flag: Bool, animate: Bool) {
        var newFrame = frameRect
        let oldFrame = self.frame
        
        if oldFrame.size.height > 0 && oldFrame.size.height != newFrame.size.height {
            switch anchorMode {
            case .bottom:
                newFrame.origin.y = oldFrame.minY
            case .top:
                newFrame.origin.y = oldFrame.maxY - newFrame.height
            case .center:
                let oldCenterY = oldFrame.midY
                newFrame.origin.y = oldCenterY - (newFrame.height / 2)
            }
        }
        
        super.setFrame(newFrame, display: flag, animate: animate)
    }
}




struct SingleOverlayContainer: View {
    let overlay: VisorProWindowManager.ActiveOverlay
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    
    @State private var hasAppeared = false
    
    private var currentOverlay: VisorProWindowManager.ActiveOverlay? {
        VisorProWindowManager.shared.allActiveOverlays.first(where: { $0.id == overlay.id })
    }
    private var isOverlayActive: Bool {
        currentOverlay != nil
    }
    
    var body: some View {
        let transitionAnchor: UnitPoint = (overlay.position.hasPrefix("top")) ? .top : .bottom
        
        ZStack {
            if hasAppeared && isOverlayActive, let current = currentOverlay {
                overlayView(for: current)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: overlay.position.hasPrefix("top") ? -40 : 40)).combined(with: .scale(scale: 0.9, anchor: transitionAnchor)),
                        removal: .opacity.combined(with: .offset(y: overlay.position.hasPrefix("top") ? -40 : 40)).combined(with: .scale(scale: 0.9, anchor: transitionAnchor))
                    ))
            } else {
                let w: CGFloat = (overlay.type == .capsLock || overlay.type == .theme) ? 230 : 260
                let h: CGFloat = (overlay.type == .media) ? 72 : 56
                Color.clear.frame(width: w, height: h).allowsHitTesting(false)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 15)
        .padding(.horizontal, 12)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: hasAppeared && isOverlayActive)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    hasAppeared = true
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
        }
    }
}
