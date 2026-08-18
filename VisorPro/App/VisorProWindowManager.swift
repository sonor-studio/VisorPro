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
        
        var finalActive: [ActiveOverlay] = []
        for pos in ["top_left", "top", "top_right", "center", "bottom_left", "bottom", "bottom_right"] {
            let items = active.filter { $0.position == pos }
            finalActive.append(contentsOf: items.prefix(limit))
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
        
        for (screenIndex, screen) in finalScreens.enumerated() {
            let screenSize = screen.visibleFrame.size
            let screenOrigin = screen.visibleFrame.origin
            
            for overlay in active {
                let windowId = "\(overlay.id)_screen_\(screenIndex)"
                let group = active.filter { $0.position == overlay.position }
                let index = group.firstIndex(of: overlay) ?? 0
                let total = group.count
                
                let x = xPos(for: overlay.position, index: index, total: total, in: screenSize) + screenOrigin.x
                let yCenter = yPos(for: overlay.position, in: screenSize) + screenOrigin.y
                
                let windowWidth: CGFloat = 400
                let windowHeight: CGFloat = overlay.type == .copy ? 2000 : ((overlay.type == .volume || overlay.type == .media || overlay.type == .battery || overlay.type == .language || overlay.type == .wifi || overlay.type == .bluetooth || overlay.type == .peripheral || overlay.type == .mic || overlay.type == .camera || overlay.type == .display || overlay.type == .fan) ? 400 : 120)
                
                let originX = x - (windowWidth / 2)
                let originY: CGFloat
                if overlay.position.hasPrefix("top") {
                    originY = yCenter + 43 - windowHeight
                } else if overlay.position.hasPrefix("bottom") {
                    originY = yCenter - 43
                } else {
                    originY = yCenter - (windowHeight / 2)
                }
                
                let targetOrigin = NSPoint(x: originX, y: originY)
                
                if let last = targetOrigins[windowId], abs(last.y - originY) > 200 {
                    windows[windowId]?.close()
                    windows.removeValue(forKey: windowId)
                    targetOrigins.removeValue(forKey: windowId)
                    shownPanels.remove(windowId)
                }
                
                let panel: NSPanel
                if let existing = windows[windowId] {
                    panel = existing
                } else {
                    panel = createPanel(for: overlay)
                    windows[windowId] = panel
                }
                let lastTarget = targetOrigins[windowId]
                let isFirstShow = !shownPanels.contains(windowId)
                
                if isFirstShow {
                    // Pierwsze pojawienie się – animacja wejścia jest obsługiwana w SwiftUI (hasAppeared)
                    shownPanels.insert(windowId)
                    targetOrigins[windowId] = targetOrigin
                    panel.alphaValue = 1
                    panel.setFrameOrigin(targetOrigin)
                    panel.orderFront(nil)
                } else if !MediaKeyManager.shared.isDisplayTransitioning {
                    if lastTarget == nil || abs(lastTarget!.x - targetOrigin.x) > 0.5 || abs(lastTarget!.y - targetOrigin.y) > 0.5 {
                        // Zmiana pozycji – animowane przesunięcie
                        targetOrigins[windowId] = targetOrigin
                        let newFrame = NSRect(origin: targetOrigin, size: panel.frame.size)
                        NSAnimationContext.runAnimationGroup { ctx in
                            ctx.duration = 0.35
                            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                            panel.animator().setFrame(newFrame, display: true)
                        }
                    }
                }
            }
        }
    }
    
    private func createPanel(for overlay: ActiveOverlay) -> NSPanel {
        let h: CGFloat = overlay.type == .copy ? 2000 : ((overlay.type == .volume || overlay.type == .media || overlay.type == .battery || overlay.type == .language || overlay.type == .wifi || overlay.type == .bluetooth || overlay.type == .peripheral || overlay.type == .mic || overlay.type == .camera || overlay.type == .display || overlay.type == .fan) ? 400 : 120)
        let panel = VisorProOverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: h),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        let view = SingleOverlayContainer(overlay: overlay)
            .environmentObject(MediaKeyManager.shared)
        
        panel.contentView = NSHostingView(rootView: view)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        
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

    private func xPos(for position: String, index: Int, total: Int, in size: CGSize) -> CGFloat {
        let averageWidth: CGFloat = 260
        let spacing: CGFloat = 24
        let margin: CGFloat = 40
        
        if position.hasSuffix("_left") {
            let startX = margin + (averageWidth / 2)
            return startX + CGFloat(index) * (averageWidth + spacing)
        } else if position.hasSuffix("_right") {
            let startX = size.width - margin - (averageWidth / 2)
            return startX - CGFloat(index) * (averageWidth + spacing)
        } else {
            let totalWidth = CGFloat(total) * averageWidth + CGFloat(max(0, total - 1)) * spacing
            let startX = (size.width - totalWidth) / 2 + (averageWidth / 2)
            return startX + CGFloat(index) * (averageWidth + spacing)
        }
    }
}

class VisorProOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { return false }
    override var canBecomeMain: Bool { return false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
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
        let h: CGFloat = overlay.type == .copy ? 2000 : ((overlay.type == .volume || overlay.type == .media || overlay.type == .battery || overlay.type == .language || overlay.type == .wifi || overlay.type == .bluetooth || overlay.type == .peripheral || overlay.type == .mic || overlay.type == .camera || overlay.type == .display) ? 400 : 120)
        let align: Alignment = {
            if overlay.position.hasPrefix("top") { return .top }
            if overlay.position.hasPrefix("bottom") { return .bottom }
            return .center
        }()
        
        let transitionAnchor: UnitPoint = (overlay.position.hasPrefix("top")) ? .top : .bottom
        
        ZStack {
            if hasAppeared && isOverlayActive, let current = currentOverlay {
                overlayView(for: current)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: overlay.position.hasPrefix("top") ? -40 : 40)).combined(with: .scale(scale: 0.9, anchor: transitionAnchor)),
                        removal: .opacity.combined(with: .offset(y: overlay.position.hasPrefix("top") ? -40 : 40)).combined(with: .scale(scale: 0.9, anchor: transitionAnchor))
                    ))
            }
        }
        .padding(.top, overlay.position.hasPrefix("top") ? 15 : 0)
        .padding(.bottom, overlay.position.hasPrefix("bottom") ? 15 : 0)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: hasAppeared && isOverlayActive)
        .frame(width: 400, height: h, alignment: align)
        .edgesIgnoringSafeArea(.all)
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
