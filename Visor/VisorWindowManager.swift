import Foundation
import AppKit
import SwiftUI
import Combine

@MainActor
class VisorWindowManager: ObservableObject {
    static let shared = VisorWindowManager()
    
    private var windows: [String: NSPanel] = [:]
    private var targetOrigins: [String: NSPoint] = [:]
    private var shownPanels: Set<String> = []
    private var cancellables = Set<AnyCancellable>()
    
    @AppStorage("volumeOverlayPosition") private var volumeOverlayPosition: String = "bottom"
    @AppStorage("batteryOverlayPosition") private var batteryOverlayPosition: String = "top"
    @AppStorage("brightnessOverlayPosition") private var brightnessOverlayPosition: String = "top"
    @AppStorage("copyOverlayPosition") private var copyOverlayPosition: String = "bottom"
    @AppStorage("capsLockOverlayPosition") private var capsLockOverlayPosition: String = "bottom"
    
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
        
        let showBattery = manager.showChargingStatus || manager.showLowBatteryWarning
        
        if manager.showVolumeIndicator { active.append(ActiveOverlay(id: "volume", type: .volume, position: volumeOverlayPosition, notification: nil)) }
        if manager.showBrightnessIndicator { active.append(ActiveOverlay(id: "brightness", type: .brightness, position: brightnessOverlayPosition, notification: nil)) }
        if showBattery { active.append(ActiveOverlay(id: "battery", type: .battery, position: batteryOverlayPosition, notification: nil)) }
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
        
        let wifiPos = UserDefaults.standard.string(forKey: "wifiOverlayPosition") ?? "bottom"
        if manager.showWiFiIndicator { active.append(ActiveOverlay(id: "wifi", type: .wifi, position: wifiPos, notification: nil)) }
        
        let periPos = UserDefaults.standard.string(forKey: "peripheralOverlayPosition") ?? "bottom"
        for notif in manager.activePeripheralNotifications {
            active.append(ActiveOverlay(id: "peripheral_\(notif.id)", type: .peripheral, position: periPos, notification: notif))
        }
        
        let limit = max(1, manager.maxSimultaneousNotifications)
        
        var finalActive: [ActiveOverlay] = []
        for pos in ["top", "center", "bottom"] {
            let items = active.filter { $0.position == pos }
            finalActive.append(contentsOf: items.prefix(limit))
        }
        return finalActive
    }
    
    func updateWindows() {
        let active = allActiveOverlays
        
        let activeIds = Set(active.map { $0.id })
        for (id, window) in windows {
            if !activeIds.contains(id) {
                // Pozwalamy SwiftUI odtworzyć animację wyjścia przez 0.35s
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    window.close()
                }
                windows.removeValue(forKey: id)
                targetOrigins.removeValue(forKey: id)
                shownPanels.remove(id)
            }
        }
        
        guard let screen = NSScreen.main else { return }
        let screenSize = screen.visibleFrame.size
        let screenOrigin = screen.visibleFrame.origin
        
        for overlay in active {
            let group = active.filter { $0.position == overlay.position }
            let index = group.firstIndex(of: overlay) ?? 0
            let total = group.count
            
            let x = xPos(for: overlay.position, index: index, total: total, in: screenSize) + screenOrigin.x
            let y = yPos(for: overlay.position, in: screenSize) + screenOrigin.y
            
            let windowWidth: CGFloat = 400
            let windowHeight: CGFloat = (overlay.type == .volume || overlay.type == .media || overlay.type == .battery) ? 400 : 120
            
            let panel: NSPanel
            if let existing = windows[overlay.id] {
                panel = existing
            } else {
                panel = createPanel(for: overlay)
                windows[overlay.id] = panel
            }
            
            let originX = x - (windowWidth / 2)
            let originY: CGFloat
            if overlay.type == .volume || overlay.type == .media || overlay.type == .battery {
                if overlay.position == "top" {
                    originY = y - windowHeight + 63
                } else if overlay.position == "bottom" {
                    originY = y - 63
                } else {
                    originY = y - (windowHeight / 2)
                }
            } else {
                originY = y - (windowHeight / 2)
            }
            
            let targetOrigin = NSPoint(x: originX, y: originY)
            let lastTarget = targetOrigins[overlay.id]
            let isFirstShow = !shownPanels.contains(overlay.id)
            
            if isFirstShow {
                // Pierwsze pojawienie się – animacja wejścia jest obsługiwana w SwiftUI (hasAppeared)
                shownPanels.insert(overlay.id)
                targetOrigins[overlay.id] = targetOrigin
                panel.alphaValue = 1
                panel.setFrameOrigin(targetOrigin)
                panel.orderFront(nil)
            } else if lastTarget == nil || abs(lastTarget!.x - targetOrigin.x) > 0.5 || abs(lastTarget!.y - targetOrigin.y) > 0.5 {
                // Zmiana pozycji – animowane przesunięcie
                targetOrigins[overlay.id] = targetOrigin
                let newFrame = NSRect(origin: targetOrigin, size: panel.frame.size)
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.35
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    panel.animator().setFrame(newFrame, display: true)
                }
            }
        }
    }
    
    private func createPanel(for overlay: ActiveOverlay) -> NSPanel {
        let h: CGFloat = (overlay.type == .volume || overlay.type == .media || overlay.type == .battery) ? 400 : 120
        let panel = VisorOverlayPanel(
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
        
        return panel
    }
    
    private func yPos(for position: String, in size: CGSize) -> CGFloat {
        let padding: CGFloat = 40
        let pillHeight: CGFloat = 56
        if position == "top" { return size.height - padding - (pillHeight / 2) } 
        if position == "center" { return size.height / 2 }
        return padding + (pillHeight / 2)
    }

    private func xPos(for position: String, index: Int, total: Int, in size: CGSize) -> CGFloat {
        let averageWidth: CGFloat = 260
        let spacing: CGFloat = 24
        let totalWidth = CGFloat(total) * averageWidth + CGFloat(max(0, total - 1)) * spacing
        let startX = (size.width - totalWidth) / 2 + (averageWidth / 2)
        return startX + CGFloat(index) * (averageWidth + spacing)
    }
}

class VisorOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { return false }
    override var canBecomeMain: Bool { return false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
}

struct SingleOverlayContainer: View {
    let overlay: VisorWindowManager.ActiveOverlay
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    
    @State private var hasAppeared = false
    private var isOverlayActive: Bool {
        VisorWindowManager.shared.allActiveOverlays.contains(where: { $0.id == overlay.id })
    }
    
    var body: some View {
        let h: CGFloat = (overlay.type == .volume || overlay.type == .media || overlay.type == .battery) ? 400 : 120
        let align: Alignment = {
            if overlay.type == .volume || overlay.type == .media || overlay.type == .battery {
                if overlay.position == "top" { return .top }
                if overlay.position == "bottom" { return .bottom }
                return .center
            }
            return .center
        }()
        
        let transitionAnchor: UnitPoint = (overlay.position == "top") ? .top : .bottom
        
        ZStack {
            if hasAppeared && isOverlayActive {
                overlayView(for: overlay)
                    .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: transitionAnchor)))
            }
        }
        .padding(.top, (overlay.type == .volume || overlay.type == .media || overlay.type == .battery) && overlay.position == "top" ? 15 : 0)
        .padding(.bottom, (overlay.type == .volume || overlay.type == .media || overlay.type == .battery) && overlay.position == "bottom" ? 15 : 0)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: hasAppeared && isOverlayActive)
        .frame(width: 400, height: h, alignment: align)
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                hasAppeared = true
            }
        }
    }
    
    @ViewBuilder
    private func overlayView(for overlay: VisorWindowManager.ActiveOverlay) -> some View {
        switch overlay.type {
        case .volume: VolumeOverlayView()
        case .brightness: BrightnessOverlayView()
        case .battery: BatteryOverlayView(isWarningMode: mediaKeyManager.showLowBatteryWarning && !mediaKeyManager.isPluggedIn)
        case .copy: CopyOverlayView()
        case .capsLock: CapsLockOverlayView()
        case .bluetooth: BluetoothOverlayView(notification: overlay.notification)
        case .language: LanguageOverlayView()
        case .media: MediaOverlayView()
        case .theme: ThemeOverlayView()
        case .mic: MicOverlayView()
        case .camera: CameraOverlayView()
        case .wifi: WiFiOverlayView()
        case .peripheral: PeripheralOverlayView(notification: overlay.notification)
        }
    }
}
