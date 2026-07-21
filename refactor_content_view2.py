import re

with open('/Users/macbook/Desktop/Dev/Visor/Visor/ContentView.swift', 'r') as f:
    content = f.read()

# Zastąp enum i funkcje activeOverlays, yPos nowym kodem
old_code = re.search(r'    enum OverlayType: String, CaseIterable \{.*?(?=    var body: some View \{)', content, re.DOTALL)

if old_code:
    new_code = """    enum OverlayType: String, CaseIterable {
        case volume, brightness, battery, copy, capsLock, bluetooth, language, media, theme, mic, camera, wifi, peripheral
    }
    
    struct ActiveOverlay: Identifiable, Equatable {
        let id: String
        let type: OverlayType
        let position: String
        let notification: DeviceNotification?
        
        static func == (lhs: ActiveOverlay, rhs: ActiveOverlay) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    private var allActiveOverlays: [ActiveOverlay] {
        var active: [ActiveOverlay] = []
        
        let showBattery = mediaKeyManager.showChargingStatus || mediaKeyManager.showLowBatteryWarning
        
        if mediaKeyManager.showVolumeIndicator { active.append(ActiveOverlay(id: "volume", type: .volume, position: volumeOverlayPosition, notification: nil)) }
        if mediaKeyManager.showBrightnessIndicator { active.append(ActiveOverlay(id: "brightness", type: .brightness, position: brightnessOverlayPosition, notification: nil)) }
        if showBattery { active.append(ActiveOverlay(id: "battery", type: .battery, position: batteryOverlayPosition, notification: nil)) }
        if mediaKeyManager.showCopyIndicator { active.append(ActiveOverlay(id: "copy", type: .copy, position: copyOverlayPosition, notification: nil)) }
        if mediaKeyManager.showCapsLockIndicator { active.append(ActiveOverlay(id: "capsLock", type: .capsLock, position: capsLockOverlayPosition, notification: nil)) }
        
        let btPos = UserDefaults.standard.string(forKey: "bluetoothOverlayPosition") ?? "bottom"
        for notif in mediaKeyManager.activeBluetoothNotifications {
            active.append(ActiveOverlay(id: "bluetooth_\\(notif.id)", type: .bluetooth, position: btPos, notification: notif))
        }
        
        let langPos = UserDefaults.standard.string(forKey: "languageOverlayPosition") ?? "bottom"
        if mediaKeyManager.showLanguageIndicator { active.append(ActiveOverlay(id: "language", type: .language, position: langPos, notification: nil)) }
        
        let mediaPos = UserDefaults.standard.string(forKey: "mediaOverlayPosition") ?? "bottom"
        if mediaKeyManager.showMediaIndicator { active.append(ActiveOverlay(id: "media", type: .media, position: mediaPos, notification: nil)) }
        
        let themePos = UserDefaults.standard.string(forKey: "themeOverlayPosition") ?? "bottom"
        if mediaKeyManager.showThemeIndicator { active.append(ActiveOverlay(id: "theme", type: .theme, position: themePos, notification: nil)) }
        
        let micPos = UserDefaults.standard.string(forKey: "micOverlayPosition") ?? "top"
        if mediaKeyManager.showMicIndicator { active.append(ActiveOverlay(id: "mic", type: .mic, position: micPos, notification: nil)) }
        
        let camPos = UserDefaults.standard.string(forKey: "cameraOverlayPosition") ?? "top"
        if mediaKeyManager.showCameraIndicator { active.append(ActiveOverlay(id: "camera", type: .camera, position: camPos, notification: nil)) }
        
        let wifiPos = UserDefaults.standard.string(forKey: "wifiOverlayPosition") ?? "bottom"
        if mediaKeyManager.showWiFiIndicator { active.append(ActiveOverlay(id: "wifi", type: .wifi, position: wifiPos, notification: nil)) }
        
        let periPos = UserDefaults.standard.string(forKey: "peripheralOverlayPosition") ?? "bottom"
        for notif in mediaKeyManager.activePeripheralNotifications {
            active.append(ActiveOverlay(id: "peripheral_\\(notif.id)", type: .peripheral, position: periPos, notification: notif))
        }
        
        let limit = max(1, mediaKeyManager.maxSimultaneousNotifications)
        
        var finalActive: [ActiveOverlay] = []
        for pos in ["top", "center", "bottom"] {
            let items = active.filter { $0.position == pos }
            finalActive.append(contentsOf: items.prefix(limit))
        }
        return finalActive
    }
    
    private func yPos(for position: String, in geo: GeometryProxy) -> CGFloat {
        let padding: CGFloat = 40
        let pillHeight: CGFloat = 56
        if position == "top" { return padding + (pillHeight / 2) }
        if position == "center" { return geo.size.height / 2 }
        return geo.size.height - padding - (pillHeight / 2)
    }

    private func xPos(for position: String, index: Int, total: Int, in geo: GeometryProxy) -> CGFloat {
        let averageWidth: CGFloat = 230
        let spacing: CGFloat = 16
        let totalWidth = CGFloat(total) * averageWidth + CGFloat(max(0, total - 1)) * spacing
        let startX = (geo.size.width - totalWidth) / 2 + (averageWidth / 2)
        return startX + CGFloat(index) * (averageWidth + spacing)
    }
    
    @ViewBuilder
    private func overlayView(for overlay: ActiveOverlay) -> some View {
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
    
"""
    content = content.replace(old_code.group(0), new_code)
else:
    print("Could not find old code block to replace")

# Teraz zastąp body
body_regex = re.search(r'        GeometryReader \{ geo in\n            ZStack \{.*?(?=\n            \}\n        \}\n        \.edgesIgnoringSafeArea)', content, re.DOTALL)

if body_regex:
    new_body = """        GeometryReader { geo in
            ZStack {
                ForEach(allActiveOverlays) { overlay in
                    let overlaysInPos = allActiveOverlays.filter { $0.position == overlay.position }
                    let index = overlaysInPos.firstIndex(of: overlay) ?? 0
                    let total = overlaysInPos.count
                    
                    overlayView(for: overlay)
                        .id(overlay.id)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .position(x: xPos(for: overlay.position, index: index, total: total, in: geo),
                                  y: yPos(for: overlay.position, in: geo))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: total)
                }"""
    content = content.replace(body_regex.group(0), new_body)
else:
    print("Could not find body block to replace")

with open('/Users/macbook/Desktop/Dev/Visor/Visor/ContentView.swift', 'w') as f:
    f.write(content)
print("ContentView updated successfully")
