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
        case volume, brightness, keyboardBrightness, battery, copy, capsLock, bluetooth, language, media, theme, mic, camera, location, wifi, peripheral, display, ram, accessoryBattery
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
        
        let showBattery = mediaKeyManager.showChargingStatus || mediaKeyManager.showLowBatteryWarning || mediaKeyManager.showUnpluggedStatus
        
        if mediaKeyManager.showVolumeIndicator { active.append(ActiveOverlay(id: "volume", type: .volume, position: volumeOverlayPosition, notification: nil)) }
        if mediaKeyManager.showBrightnessIndicator { active.append(ActiveOverlay(id: "brightness", type: .brightness, position: brightnessOverlayPosition, notification: nil)) }
        if mediaKeyManager.showKeyboardBrightnessIndicator { active.append(ActiveOverlay(id: "keyboardBrightness", type: .keyboardBrightness, position: keyboardBrightnessOverlayPosition, notification: nil)) }
        if showBattery { 
            let batId = (mediaKeyManager.showLowBatteryWarning && !mediaKeyManager.isPluggedIn) ? "battery_warning" : "battery_charging"
            active.append(ActiveOverlay(id: batId, type: .battery, position: batteryOverlayPosition, notification: nil)) 
        }
        if mediaKeyManager.showCopyIndicator { active.append(ActiveOverlay(id: "copy_\(mediaKeyManager.clipboardEventId)", type: .copy, position: copyOverlayPosition, notification: nil)) }
        if mediaKeyManager.showCapsLockIndicator { active.append(ActiveOverlay(id: "capsLock_\(mediaKeyManager.capsLockEventId)", type: .capsLock, position: capsLockOverlayPosition, notification: nil)) }
        
        let btPos = MediaKeyManager.shared.getOverlayPosition(for: "bluetoothOverlayPosition")
        for notif in mediaKeyManager.activeBluetoothNotifications {
            active.append(ActiveOverlay(id: "bluetooth_\(notif.id)", type: .bluetooth, position: btPos, notification: notif))
        }
        
        let langPos = MediaKeyManager.shared.getOverlayPosition(for: "languageOverlayPosition")
        if mediaKeyManager.showLanguageIndicator { active.append(ActiveOverlay(id: "language", type: .language, position: langPos, notification: nil)) }
        
        let mediaPos = MediaKeyManager.shared.getOverlayPosition(for: "mediaOverlayPosition")
        if mediaKeyManager.showMediaIndicator { active.append(ActiveOverlay(id: "media", type: .media, position: mediaPos, notification: nil)) }
        
        let themePos = MediaKeyManager.shared.getOverlayPosition(for: "themeOverlayPosition")
        if mediaKeyManager.showThemeIndicator { active.append(ActiveOverlay(id: "theme", type: .theme, position: themePos, notification: nil)) }
        
        let micPos = MediaKeyManager.shared.getOverlayPosition(for: "micOverlayPosition")
        if mediaKeyManager.showMicIndicator { active.append(ActiveOverlay(id: "mic", type: .mic, position: micPos, notification: nil)) }
        
        let camPos = MediaKeyManager.shared.getOverlayPosition(for: "cameraOverlayPosition")
        if mediaKeyManager.showCameraIndicator { active.append(ActiveOverlay(id: "camera", type: .camera, position: camPos, notification: nil)) }
        
        let locPos = MediaKeyManager.shared.getOverlayPosition(for: "locationOverlayPosition")
        if mediaKeyManager.showLocationIndicator { active.append(ActiveOverlay(id: "location", type: .location, position: locPos, notification: nil)) }
        
        let wifiPos = MediaKeyManager.shared.getOverlayPosition(for: "wifiOverlayPosition")
        if mediaKeyManager.showWiFiIndicator { active.append(ActiveOverlay(id: "wifi", type: .wifi, position: wifiPos, notification: nil)) }
        
        let periPos = MediaKeyManager.shared.getOverlayPosition(for: "peripheralOverlayPosition")
        for notif in mediaKeyManager.activePeripheralNotifications {
            active.append(ActiveOverlay(id: "peripheral_\(notif.id)", type: .peripheral, position: periPos, notification: notif))
        }
        
        let displayPos = MediaKeyManager.shared.getOverlayPosition(for: "displayOverlayPosition")
        for notif in mediaKeyManager.activeDisplayNotifications {
            active.append(ActiveOverlay(id: "display_\(notif.id)", type: .display, position: displayPos, notification: notif))
        }
        
        
        let ramPos = MediaKeyManager.shared.getOverlayPosition(for: "ramOverlayPosition")
        if mediaKeyManager.showRamIndicator { active.append(ActiveOverlay(id: "ram", type: .ram, position: ramPos, notification: nil)) }
        
        if mediaKeyManager.showAccessoryBatteryIndicator {
            active.append(ActiveOverlay(id: "accessoryBattery", type: .accessoryBattery, position: batteryOverlayPosition, notification: nil))
        }
        
        let limit = max(1, mediaKeyManager.maxSimultaneousNotifications)
        
        let topCandidates = active.filter { $0.position.hasPrefix("top") }
        let topToKeep = Set(topCandidates.prefix(limit).map { $0.id })
            
        let bottomCandidates = active.filter { $0.position.hasPrefix("bottom") }
        let bottomToKeep = Set(bottomCandidates.prefix(limit).map { $0.id })
            
        var finalActive: [ActiveOverlay] = []
        for overlay in active {
            if topToKeep.contains(overlay.id) || bottomToKeep.contains(overlay.id) {
                finalActive.append(overlay)
            }
        }
        
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

    private func computeLayerPositions(overlays: [ActiveOverlay], limit: Int, size: CGSize) -> [String: CGFloat] {
        let lefts = overlays.filter { $0.position.hasSuffix("_left") }
        let rights = overlays.filter { $0.position.hasSuffix("_right") }
        let centers = overlays.filter { !$0.position.hasSuffix("_left") && !$0.position.hasSuffix("_right") }
        
        let w: CGFloat = 260
        let s: CGFloat = 24
        let m: CGFloat = 40
        
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
    
    private func yPos(for overlay: ActiveOverlay, in size: CGSize) -> CGFloat {
        let padding: CGFloat = 40
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
        case .ram: RamOverlayView()
        case .accessoryBattery: AccessoryBatteryOverlayView()
        }
    }
    
    var body: some View {
        let showBattery = mediaKeyManager.showChargingStatus || mediaKeyManager.showLowBatteryWarning || mediaKeyManager.showUnpluggedStatus
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
        let showRam = mediaKeyManager.showRamIndicator
        
        let isVisible = showBattery || showVolume || showBrightness || showKeyboardBrightness || showCopy || showCapsLock || showBluetooth || showLanguage || showMedia || showTheme || showMic || showCamera || showLocation || showWiFi || showPeripheral || showDisplay || showRam
        
        
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
            let topPositions = computeLayerPositions(overlays: topOverlays, limit: limit, size: geoSize)
            let bottomPositions = computeLayerPositions(overlays: bottomOverlays, limit: limit, size: geoSize)
            let allPositions = topPositions.merging(bottomPositions) { (current, _) in current }
            
            ForEach(allActiveOverlays) { overlay in
                let xPosition = allPositions[overlay.id] ?? (geoSize.width / 2)
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
            
            window.setFrame(screen.visibleFrame, display: true)
        }
    }
}





#Preview {
    ContentView()
        .environmentObject(MediaKeyManager())
}












import SwiftUI


