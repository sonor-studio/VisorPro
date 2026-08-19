import SwiftUI

struct ContentView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager

    @AppStorage("volumeOverlayPosition") private var volumeOverlayPosition: String = "bottom"
    @AppStorage("batteryOverlayPosition") private var batteryOverlayPosition: String = "top"
    @AppStorage("brightnessOverlayPosition") private var brightnessOverlayPosition: String = "top"
    @AppStorage("keyboardBrightnessOverlayPosition") private var keyboardBrightnessOverlayPosition: String = "top"
    @AppStorage("copyOverlayPosition") private var copyOverlayPosition: String = "bottom"
    @AppStorage("capsLockOverlayPosition") private var capsLockOverlayPosition: String = "bottom"
    @State private var overlayWindow: NSWindow? = nil
    @State private var geoSize: CGSize = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1920, height: 1080)
    
    enum OverlayType: String, CaseIterable {
        case volume, brightness, keyboardBrightness, battery, copy, capsLock, bluetooth, language, media, theme, mic, camera, location, wifi, peripheral, display, fan
    }
    
    struct ActiveOverlay: Identifiable, Equatable {
        let id: String
        let type: OverlayType
        let position: String
        let notification: DeviceNotification?
        
        static func == (lhs: ActiveOverlay, rhs: ActiveOverlay) -> Bool {
            lhs.id == rhs.id && lhs.type == rhs.type && lhs.notification == rhs.notification
        }
    }
    
    private var allActiveOverlays: [ActiveOverlay] {
        var active: [ActiveOverlay] = []
        
        let showBattery = mediaKeyManager.showChargingStatus || mediaKeyManager.showLowBatteryWarning
        
        if mediaKeyManager.showVolumeIndicator { active.append(ActiveOverlay(id: "volume", type: .volume, position: volumeOverlayPosition, notification: nil)) }
        if mediaKeyManager.showBrightnessIndicator { active.append(ActiveOverlay(id: "brightness", type: .brightness, position: brightnessOverlayPosition, notification: nil)) }
        if mediaKeyManager.showKeyboardBrightnessIndicator { active.append(ActiveOverlay(id: "keyboardBrightness", type: .keyboardBrightness, position: keyboardBrightnessOverlayPosition, notification: nil)) }
        if showBattery { 
            let batId = (mediaKeyManager.showLowBatteryWarning && !mediaKeyManager.isPluggedIn) ? "battery_warning" : "battery_charging"
            active.append(ActiveOverlay(id: batId, type: .battery, position: batteryOverlayPosition, notification: nil)) 
        }
        if mediaKeyManager.showCopyIndicator { active.append(ActiveOverlay(id: "copy_\(mediaKeyManager.clipboardEventId)", type: .copy, position: copyOverlayPosition, notification: nil)) }
        if mediaKeyManager.showCapsLockIndicator { active.append(ActiveOverlay(id: "capsLock_\(mediaKeyManager.capsLockEventId)", type: .capsLock, position: capsLockOverlayPosition, notification: nil)) }
        
        let btPos = UserDefaults.standard.string(forKey: "bluetoothOverlayPosition") ?? "bottom"
        for notif in mediaKeyManager.activeBluetoothNotifications {
            active.append(ActiveOverlay(id: "bluetooth_\(notif.id)", type: .bluetooth, position: btPos, notification: notif))
        }
        
        let langPos = UserDefaults.standard.string(forKey: "languageOverlayPosition") ?? "bottom"
        if mediaKeyManager.showLanguageIndicator { active.append(ActiveOverlay(id: "language_\(mediaKeyManager.languageEventId)", type: .language, position: langPos, notification: nil)) }
        
        let mediaPos = UserDefaults.standard.string(forKey: "mediaOverlayPosition") ?? "bottom"
        if mediaKeyManager.showMediaIndicator { active.append(ActiveOverlay(id: "media_\(mediaKeyManager.mediaEventId)", type: .media, position: mediaPos, notification: nil)) }
        
        let themePos = UserDefaults.standard.string(forKey: "themeOverlayPosition") ?? "bottom"
        if mediaKeyManager.showThemeIndicator { active.append(ActiveOverlay(id: "theme_\(mediaKeyManager.themeEventId)", type: .theme, position: themePos, notification: nil)) }
        
        let micPos = UserDefaults.standard.string(forKey: "micOverlayPosition") ?? "top"
        if mediaKeyManager.showMicIndicator { active.append(ActiveOverlay(id: "mic_\(mediaKeyManager.micEventId)", type: .mic, position: micPos, notification: nil)) }
        
        let camPos = UserDefaults.standard.string(forKey: "cameraOverlayPosition") ?? "top"
        if mediaKeyManager.showCameraIndicator { active.append(ActiveOverlay(id: "camera_\(mediaKeyManager.cameraEventId)", type: .camera, position: camPos, notification: nil)) }
        
        let locPos = UserDefaults.standard.string(forKey: "locationOverlayPosition") ?? "top"
        if mediaKeyManager.showLocationIndicator { active.append(ActiveOverlay(id: "location_\(mediaKeyManager.locationEventId)", type: .location, position: locPos, notification: nil)) }
        
        let wifiPos = UserDefaults.standard.string(forKey: "wifiOverlayPosition") ?? "bottom"
        if mediaKeyManager.showWiFiIndicator { active.append(ActiveOverlay(id: "wifi_\(mediaKeyManager.wiFiEventId)", type: .wifi, position: wifiPos, notification: nil)) }
        
        let periPos = UserDefaults.standard.string(forKey: "peripheralOverlayPosition") ?? "bottom"
        for notif in mediaKeyManager.activePeripheralNotifications {
            active.append(ActiveOverlay(id: "peripheral_\(notif.id)", type: .peripheral, position: periPos, notification: notif))
        }
        
        let displayPos = UserDefaults.standard.string(forKey: "displayOverlayPosition") ?? "bottom"
        for notif in mediaKeyManager.activeDisplayNotifications {
            active.append(ActiveOverlay(id: "display_\(notif.id)", type: .display, position: displayPos, notification: notif))
        }
        
        let fanPos = UserDefaults.standard.string(forKey: "fanOverlayPosition") ?? "bottom"
        if mediaKeyManager.showFanIndicator { active.append(ActiveOverlay(id: "fan_\(mediaKeyManager.fanEventId)", type: .fan, position: fanPos, notification: nil)) }
        
        let limit = max(1, mediaKeyManager.maxSimultaneousNotifications)
        
        let topOverlays = active.filter { $0.position.hasPrefix("top") }.prefix(limit)
        let bottomOverlays = active.filter { $0.position.hasPrefix("bottom") }.prefix(limit)
            
        var finalActive: [ActiveOverlay] = []
        finalActive.append(contentsOf: topOverlays)
        finalActive.append(contentsOf: bottomOverlays)
        
        return finalActive
    }
    
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
    
    private func yPos(for overlay: ActiveOverlay, in size: CGSize) -> CGFloat {
        let padding: CGFloat = 40
        // Ustalmy prawdziwą wysokość pigułki w zależności od typu, żeby krawędzie (górna/dolna) idealnie się licowały!
        let pillHeight: CGFloat = 56
        
        if overlay.position.hasPrefix("top") { return padding + (pillHeight / 2) } 
        if overlay.position == "center" { return size.height / 2 }
        return size.height - padding - (pillHeight / 2)
    }
    
    @ViewBuilder
    private func overlayView(for overlay: ActiveOverlay) -> some View {
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
    
    var body: some View {
        let showBattery = mediaKeyManager.showChargingStatus || mediaKeyManager.showLowBatteryWarning
        let showVolume = mediaKeyManager.showVolumeIndicator
        let showBrightness = mediaKeyManager.showBrightnessIndicator
        let showKeyboardBrightness = mediaKeyManager.showKeyboardBrightnessIndicator
        let showCopy = mediaKeyManager.showCopyIndicator
        let showCapsLock = mediaKeyManager.showCapsLockIndicator
        let showBluetooth = !mediaKeyManager.activeBluetoothNotifications.isEmpty
        let showLanguage = mediaKeyManager.showLanguageIndicator
        let showMedia = mediaKeyManager.showMediaIndicator
        let showTheme = mediaKeyManager.showThemeIndicator
        let showMic = mediaKeyManager.showMicIndicator
        let showCamera = mediaKeyManager.showCameraIndicator
        let showLocation = mediaKeyManager.showLocationIndicator
        let showWiFi = mediaKeyManager.showWiFiIndicator
        let showPeripheral = !mediaKeyManager.activePeripheralNotifications.isEmpty
        let showDisplay = !mediaKeyManager.activeDisplayNotifications.isEmpty
        let showFan = mediaKeyManager.showFanIndicator
        
        let isVisible = showBattery || showVolume || showBrightness || showKeyboardBrightness || showCopy || showCapsLock || showBluetooth || showLanguage || showMedia || showTheme || showMic || showCamera || showLocation || showWiFi || showPeripheral || showDisplay || showFan
        
        
        ZStack {
            GeometryReader { geo in
                Color.clear
                    .onAppear { self.geoSize = geo.size }
                    .onChange(of: geo.size) { _, new in self.geoSize = new }
            }
            .allowsHitTesting(false)
            
            let limit = max(1, mediaKeyManager.maxSimultaneousNotifications)
            let topOverlays = allActiveOverlays.filter { $0.position.hasPrefix("top") }
            let bottomOverlays = allActiveOverlays.filter { $0.position.hasPrefix("bottom") }
            let topSlots = assignSlots(overlays: topOverlays, limit: limit)
            let bottomSlots = assignSlots(overlays: bottomOverlays, limit: limit)
            let allSlots = topSlots.merging(bottomSlots) { (current, _) in current }
            
            ForEach(allActiveOverlays) { overlay in
                let assignedSlot = allSlots[overlay.id] ?? 0
                
                let xPosition = getSlotX(index: assignedSlot, totalSlots: limit, in: geoSize)
                let yPosition = yPos(for: overlay, in: geoSize)
                
                overlayView(for: overlay)
                    .ignoresSafeArea()
                    .id(overlay.id)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .position(x: xPosition, y: yPosition)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onChange(of: isVisible) { _, visible in
            if visible {
                repositionWindow()
            }
        }
    }
    
    private func repositionWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let window = overlayWindow else { return }
            guard let screen = NSScreen.main else { return }
            
            // Okno na cały ekran - ContentView zarządza pozycją przez GeometryReader
            window.setFrame(screen.visibleFrame, display: true)
        }
    }
}




// Widok pomocniczy pozwalający animować wyświetlaną liczbę

#Preview {
    ContentView()
        .environmentObject(MediaKeyManager())
}












import SwiftUI


