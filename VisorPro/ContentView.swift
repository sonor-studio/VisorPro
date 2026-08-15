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
        case volume, brightness, keyboardBrightness, battery, copy, capsLock, bluetooth, language, media, theme, mic, camera, wifi, peripheral
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
        
        let wifiPos = UserDefaults.standard.string(forKey: "wifiOverlayPosition") ?? "bottom"
        if mediaKeyManager.showWiFiIndicator { active.append(ActiveOverlay(id: "wifi_\(mediaKeyManager.wiFiEventId)", type: .wifi, position: wifiPos, notification: nil)) }
        
        let periPos = UserDefaults.standard.string(forKey: "peripheralOverlayPosition") ?? "bottom"
        for notif in mediaKeyManager.activePeripheralNotifications {
            active.append(ActiveOverlay(id: "peripheral_\(notif.id)", type: .peripheral, position: periPos, notification: notif))
        }
        
        let limit = max(1, mediaKeyManager.maxSimultaneousNotifications)
        
        var finalActive: [ActiveOverlay] = []
        for pos in ["top", "center", "bottom"] {
            let items = active.filter { $0.position == pos }
            finalActive.append(contentsOf: items.prefix(limit))
        }
        return finalActive
    }
    
    private func xPos(for position: String, index: Int, total: Int, in size: CGSize) -> CGFloat {
        let averageWidth: CGFloat = 260
        let spacing: CGFloat = 24
        let totalWidth = CGFloat(total) * averageWidth + CGFloat(max(0, total - 1)) * spacing
        let startX = (size.width - totalWidth) / 2 + (averageWidth / 2)
        return startX + CGFloat(index) * (averageWidth + spacing)
    }
    
    private func yPos(for overlay: ActiveOverlay, in size: CGSize) -> CGFloat {
        let padding: CGFloat = 40
        // Ustalmy prawdziwą wysokość pigułki w zależności od typu, żeby krawędzie (górna/dolna) idealnie się licowały!
        let pillHeight: CGFloat = 56
        
        if overlay.position == "top" { return padding + (pillHeight / 2) } 
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
        case .wifi: WiFiOverlayView()
        case .peripheral: PeripheralOverlayView(notification: overlay.notification)
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
        let showWiFi = mediaKeyManager.showWiFiIndicator
        let showPeripheral = !mediaKeyManager.activePeripheralNotifications.isEmpty
        
        let isVisible = showBattery || showVolume || showBrightness || showKeyboardBrightness || showCopy || showCapsLock || showBluetooth || showLanguage || showMedia || showTheme || showMic || showCamera || showWiFi || showPeripheral
        
        let btPos = UserDefaults.standard.string(forKey: "bluetoothOverlayPosition") ?? "bottom"
        let langPos = UserDefaults.standard.string(forKey: "languageOverlayPosition") ?? "bottom"
        let mediaPos = UserDefaults.standard.string(forKey: "mediaOverlayPosition") ?? "bottom"
        let themePos = UserDefaults.standard.string(forKey: "themeOverlayPosition") ?? "bottom"
        let micPos = UserDefaults.standard.string(forKey: "micOverlayPosition") ?? "top"
        let camPos = UserDefaults.standard.string(forKey: "cameraOverlayPosition") ?? "top"
        let wifiPos = UserDefaults.standard.string(forKey: "wifiOverlayPosition") ?? "bottom"
        let periPos = UserDefaults.standard.string(forKey: "peripheralOverlayPosition") ?? "bottom"
        
        ZStack {
            GeometryReader { geo in
                Color.clear
                    .onAppear { self.geoSize = geo.size }
                    .onChange(of: geo.size) { _, new in self.geoSize = new }
            }
            .allowsHitTesting(false)
            
            ForEach(allActiveOverlays) { overlay in
                let overlaysInPos = allActiveOverlays.filter { $0.position == overlay.position }
                let index = overlaysInPos.firstIndex(of: overlay) ?? 0
                let total = overlaysInPos.count
                
                let xPosition = xPos(for: overlay.position, index: index, total: total, in: geoSize)
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

struct BatteryOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @Environment(\.colorScheme) var colorScheme
    @State private var animatedBatteryProgress: CGFloat = 0.0
    @State private var isPulsing: Bool = false
    @State private var isExpanded: Bool = false
    @State private var isHovering: Bool = false
    @State private var expandedKeepAliveTimer: Timer? = nil
    
    var isWarningMode: Bool = false
    var isPreview: Bool = false
    
    private var actualPercentage: Int {
        isPreview ? 82 : mediaKeyManager.currentBatteryPercentage
    }
    
    private var actualIsPluggedIn: Bool {
        isPreview ? true : mediaKeyManager.isPluggedIn
    }
    
    private var batteryColor: Color {
        if isWarningMode { return .red }
        if actualPercentage <= 20 {
            return .red
        } else if actualPercentage <= 50 {
            return .yellow
        } else {
            return .green
        }
    }
    
    private var iconName: String {
        if isWarningMode {
            return actualPercentage <= 10 ? "battery.0" : "battery.25"
        }
        return actualIsPluggedIn ? "bolt.fill" : (actualPercentage > 50 ? "battery.75" : "battery.50")
    }
    
    private func mockedTimeRemaining(for percentage: Int) -> String {
        return isPreview ? "About 1h 20m to full" : mediaKeyManager.batteryTimeRemaining
    }
    
    var body: some View {
        let width: CGFloat = 260
        let baseHeight: CGFloat = 56
        let expandedHeight: CGFloat = 160
        let trackPadding: CGFloat = 4
        let innerPadding: CGFloat = 3
        let outerRadius: CGFloat = baseHeight / 2
        
        let trackWidth = width - (trackPadding * 2)
        let trackHeight = baseHeight - (trackPadding * 2)
        let innerWidth = trackWidth - (innerPadding * 2)
        let innerHeight = trackHeight - (innerPadding * 2)
        
        VStack(spacing: 0) {
            ZStack(alignment: .leading) {
                // WARSTWA 1: Baza
                ZStack {
                    CustomCapsule()
                        .stroke(Color.primary.opacity(0.15), style: StrokeStyle(lineWidth: innerPadding, lineCap: .round))
                        .frame(width: trackWidth - innerPadding, height: trackHeight - innerPadding)
                }
                .frame(width: width, height: baseHeight)
                
                // WARSTWA 2: Pasek postępu baterii (dookoła)
                CustomCapsule()
                    .trim(from: 0, to: animatedBatteryProgress)
                    .stroke(batteryColor, style: StrokeStyle(lineWidth: innerPadding, lineCap: .round))
                    .frame(width: trackWidth - innerPadding, height: trackHeight - innerPadding)
                    .padding(.leading, trackPadding + (innerPadding / 2.0))
                    .opacity(isWarningMode && isPulsing ? 0.3 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
                
                // WARSTWA 3: Górna warstwa
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if actualPercentage == 100 {
                            Text("Connected")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                            AnimatablePercentageText(progress: animatedBatteryProgress, isTopTitle: false, color: .primary, isPluggedIn: actualIsPluggedIn)
                        } else {
                            AnimatablePercentageText(progress: animatedBatteryProgress, isTopTitle: true, color: .primary, isPluggedIn: actualIsPluggedIn)
                            MarqueeText(text: mockedTimeRemaining(for: actualPercentage), font: .system(size: 11, weight: .bold, design: .rounded), foregroundColor: .secondary)
                        }
                    }
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16)
                .frame(width: innerWidth, height: innerHeight)
                .background(
                    Color.clear.background(.regularMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.glassBorder, lineWidth: 1))
                )
                .padding(.leading, trackPadding + innerPadding)
                
                // WTYCZKA (Na samej górze, nad szkłem, czysty kolor batteryColor)
                if !isWarningMode && actualIsPluggedIn {
                    Image(systemName: "powerplug.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.bottom, 1.0)
                        .foregroundColor(batteryColor)
                        .brightness(-0.1)
                        .modifier(PlugIconMover(
                            progress: animatedBatteryProgress,
                            targetProgress: CGFloat(actualPercentage) / 100.0,
                            width: trackWidth - innerPadding,
                            height: trackHeight - innerPadding
                        ))
                }
            }
            .frame(width: width, height: baseHeight)
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in }
                    .onEnded { value in
                        let moved = abs(value.translation.width) >= 8 || abs(value.translation.height) >= 8
                        if !moved {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                isExpanded.toggle()
                            }
                        }
                    }
            )
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isWarningMode ? "Condition" : "Power")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(isWarningMode ? mediaKeyManager.batteryCondition : mediaKeyManager.batteryPowerDraw)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    
                    Divider()
                        .frame(height: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Capacity")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text("\(mediaKeyManager.batteryHealthPercentage)%")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    
                    Divider()
                        .frame(height: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cycles")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text("\(mediaKeyManager.batteryCycleCount)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                
                Button(action: {
                    if !isPreview {
                        mediaKeyManager.openBatterySettings()
                    }
                }) {
                    Text("Open Battery Settings")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .frame(width: width, height: isExpanded ? expandedHeight - baseHeight : 0, alignment: .top)
            .clipped()
            .opacity(isExpanded ? 1 : 0)
        }
        .background(
            Color.clear.background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: outerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                        .strokeBorder(Color.glassBorder, lineWidth: 1)
                        .opacity(isExpanded ? 1 : 0)
                )
        )
        .frame(width: width, height: isExpanded ? expandedHeight : baseHeight, alignment: .top)
        .onHoverExact { hovering in
            isHovering = hovering
            if !isPreview {
                mediaKeyManager.keepAlive(for: "battery", isHovering: hovering || isExpanded)
            }
        }
        .onChange(of: isExpanded) { expanded in
            if expanded {
                expandedKeepAliveTimer?.invalidate()
                expandedKeepAliveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    DispatchQueue.main.async {
                        if !isPreview {
                            mediaKeyManager.keepAlive(for: "battery", isHovering: true)
                            mediaKeyManager.refreshBatteryState()
                        }
                    }
                }
            } else {
                expandedKeepAliveTimer?.invalidate()
                expandedKeepAliveTimer = nil
                if !isPreview {
                    mediaKeyManager.keepAlive(for: "battery", isHovering: isHovering)
                }
            }
        }
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(20)
        .applyTheme(mediaKeyManager.overlayTheme)
        .onAppear {
            let targetProgress = CGFloat(actualPercentage) / 100.0
            
            // W trybie ostrzegawczym animujemy ZMNIEJSZANIE się baterii od 100% do celu
            animatedBatteryProgress = isWarningMode ? 1.0 : 0.0
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let distance = isWarningMode ? (1.0 - targetProgress) : targetProgress
                let actualDuration = isWarningMode ? 2.2 : (3.5 * Double(distance))
                
                let animation: Animation
                if isWarningMode {
                    animation = Animation.easeOut(duration: actualDuration)
                } else {
                    animation = Animation.timingCurve(0.4, 0.0, 0.2, 1.0, duration: actualDuration)
                }
                
                withAnimation(animation) {
                    animatedBatteryProgress = targetProgress
                }
            }
            
            if isWarningMode {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    isPulsing = true
                }
            }
        }
        .onChange(of: actualPercentage) { newValue in
            withAnimation(.easeInOut(duration: 0.8)) {
                animatedBatteryProgress = CGFloat(newValue) / 100.0
            }
        }
    }
}

// Widok pomocniczy pozwalający animować wyświetlaną liczbę
struct AnimatablePercentageText: View, Animatable {
    var progress: CGFloat
    var isTopTitle: Bool = false
    var color: Color = .white
    var isPluggedIn: Bool = true
    var customText: String? = nil
    
    // Zmiana typu na AnimatablePair naprawia znany błąd SwiftUI, w którym animacja
    // przejścia (np. move) nadpisuje zmienną animatableData i powoduje wartości typu -100.
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(progress, 0) }
        set { progress = newValue.first }
    }
    
    private var displayText: String {
        let percentage = max(0, min(100, Int(progress * 100)))
        let statusText = isPluggedIn ? "charged" : "remaining"
        if let customText = customText {
            return customText.replacingOccurrences(of: "%d", with: "\(percentage)")
        } else {
            return percentage == 100 && !isTopTitle ? "Fully charged" : "\(percentage)% \(statusText)"
        }
    }
    
    var body: some View {
        Group {
            if customText == "%d%" {
                ZStack(alignment: .trailing) {
                    Text("100%")
                        .font(.system(size: isTopTitle ? 16 : 13, weight: isTopTitle ? .bold : .medium, design: isTopTitle ? .rounded : .default))
                        .monospacedDigit()
                        .hidden()
                    
                    Text(displayText)
                        .font(.system(size: isTopTitle ? 16 : 13, weight: isTopTitle ? .bold : .medium, design: isTopTitle ? .rounded : .default))
                        .monospacedDigit()
                        .foregroundColor(color)
                        .animation(nil, value: displayText)
                }
            } else {
                Text(displayText)
                    .font(.system(size: isTopTitle ? 16 : 13, weight: isTopTitle ? .bold : .medium, design: isTopTitle ? .rounded : .default))
                    .monospacedDigit()
                    .foregroundColor(color)
                    .animation(nil, value: displayText)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

#Preview {
    ContentView()
        .environmentObject(MediaKeyManager())
}

struct PlugIconMover: AnimatableModifier {
    var progress: CGFloat
    var targetProgress: CGFloat
    var width: CGFloat
    var height: CGFloat
    
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(progress, 0) }
        set { progress = newValue.first }
    }
    
    func getPosition(for d: CGFloat, S1: CGFloat, S2: CGFloat, S3: CGFloat, S4: CGFloat, S5: CGFloat) -> CGPoint {
        let r = height / 2
        var x: CGFloat = 0
        var y: CGFloat = 0
        
        if d <= S1 {
            let p = d / S1
            let a = 180.0 + Double(p) * 90.0
            x = r + r * cos(a * .pi / 180)
            y = r + r * sin(a * .pi / 180)
        } else if d <= S1 + S2 {
            let p = (d - S1) / S2
            x = r + p * S2
            y = 0
        } else if d <= S1 + S2 + S3 {
            let p = (d - S1 - S2) / S3
            let a = -90.0 + Double(p) * 180.0
            x = (width - r) + r * cos(a * .pi / 180)
            y = r + r * sin(a * .pi / 180)
        } else if d <= S1 + S2 + S3 + S4 {
            let p = (d - S1 - S2 - S3) / S4
            x = (width - r) - p * S4
            y = height
        } else {
            let p = (d - S1 - S2 - S3 - S4) / S5
            let a = 90.0 + Double(p) * 90.0
            x = r + r * cos(a * .pi / 180)
            y = r + r * sin(a * .pi / 180)
        }
        return CGPoint(x: x, y: y)
    }
    
    func body(content: Content) -> some View {
        let r = height / 2
        let l = width - height
        
        let S1 = .pi * r / 2
        let S2 = l
        let S3 = .pi * r
        let S4 = l
        let S5 = .pi * r / 2
        
        let total = S1 + S2 + S3 + S4 + S5
        
        let safeProgress = max(0, min(1, progress))
        let d = safeProgress * total
        
        let pCenter = getPosition(for: d, S1: S1, S2: S2, S3: S3, S4: S4, S5: S5)
        
        var angle: Double = 0
        if d <= 0 { angle = 270.0 }
        else if d <= S1 { angle = 270.0 + Double(d / S1) * 90.0 }
        else if d <= S1 + S2 { angle = 360.0 }
        else if d <= S1 + S2 + S3 { angle = 360.0 + Double((d - S1 - S2) / S3) * 180.0 }
        else if d <= S1 + S2 + S3 + S4 { angle = 540.0 }
        else if d < total { 
            let p = (d - S1 - S2 - S3 - S4) / S5
            // Zgodnie z prośbą, opóźniamy start rotacji na ostatnim zakręcie jeszcze bardziej.
            // Blokujemy obrót przez pierwsze 70% zakrętu,
            // a przez pozostałe 30% wtyczka wykonuje bardzo ostry, błyskawiczny obrót.
            let delayedP = p < 0.7 ? 0.0 : (p - 0.7) / 0.3
            angle = 540.0 + Double(delayedP) * 90.0 
        }
        else { angle = 630.0 }
        
        // Standardowe znikanie wtyczki:
        var fadeOutEnd = max(0, min(1, targetProgress)) * total
        var fadeOutStart = fadeOutEnd - 120.0
        
        // Zgodnie z prośbą: przy pełnych 100% chcemy, by zniknęła jeszcze PRZED ostatnim zakrętem (S5)
        if targetProgress >= 0.99 {
            fadeOutEnd = total - S5
            fadeOutStart = fadeOutEnd - 60.0
        }
        
        var iconOpacity: Double = 1.0
        if d > fadeOutStart {
            if d >= fadeOutEnd {
                iconOpacity = 0.0
            } else {
                iconOpacity = 1.0 - Double((d - fadeOutStart) / (fadeOutEnd - fadeOutStart))
            }
        }
        
        // Dodajemy stały offset +5.5 na osiach X i Y (trackPadding + innerPadding/2). 
        return content
            .rotationEffect(.degrees(angle))
            .position(x: pCenter.x + 5.5, y: pCenter.y + 5.5)
            .opacity(iconOpacity)
    }
}

struct CustomCapsule: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = rect.height / 2
        let l = rect.width - rect.height
        
        path.move(to: CGPoint(x: 0, y: r)) // Środek po lewej
        path.addArc(center: CGPoint(x: r, y: r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.addLine(to: CGPoint(x: r + l, y: 0))
        path.addArc(center: CGPoint(x: r + l, y: r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: r, y: rect.height))
        path.addArc(center: CGPoint(x: r, y: r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        
        return path
    }
}

struct VolumeOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("volumeFillCenter") private var volumeFillCenter: Bool = true
    @State private var animatedVolumeProgress: CGFloat = 0.0
    var isPreview: Bool = false
    
    private var actualVolume: Int {
        isPreview ? 65 : mediaKeyManager.currentVolume
    }
    
    private var actualIsMuted: Bool {
        isPreview ? false : mediaKeyManager.isMuted
    }
    
    private var iconName: String {
        if actualIsMuted || actualVolume == 0 {
            return "speaker.slash.fill"
        } else if actualVolume < 33 {
            return "speaker.wave.1.fill"
        } else if actualVolume < 66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
    @State private var isExpanded: Bool = false
    @State private var isHovering: Bool = false
    @State private var availableDevices: [(id: UInt32, name: String)] = []
    
    @AppStorage("overlayExpansionStyle") private var overlayExpansionStyle: String = "drawer"
    
    @State private var expandedKeepAliveTimer: Timer? = nil

    var body: some View {
        let currentDevices = isPreview ? [(id: UInt32(1), name: "MacBook Pro Speakers"), (id: UInt32(2), name: "AirPods Pro")] : availableDevices
        let maxListHeight: CGFloat = 160
        let listHeight = currentDevices.isEmpty ? 0 : min(CGFloat(currentDevices.count * 40 + 10), maxListHeight)
        let volPos = UserDefaults.standard.string(forKey: "volumeOverlayPosition") ?? "bottom"
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            progress: animatedVolumeProgress,
            barColor: .blue,
            fillCenter: volumeFillCenter,
            isMuted: actualIsMuted,
            listHeight: listHeight,
            supportDragGesture: true,
            onDrag: { v in
                mediaKeyManager.setVolume(to: Int(v * 100))
            },
            onLeftTap: {
                mediaKeyManager.toggleVolumeMute()
            },
            onRightTap: {
                if !isExpanded {
                    availableDevices = VolumeManager.shared.getAvailableOutputDevices()
                }
            },
            expandUpwards: volPos == "bottom",
            baseContent: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(actualIsMuted ? .secondary : .primary)
                        .frame(width: 26, height: 24)
                    
                    MarqueeText(text: actualIsMuted ? "Muted" : mediaKeyManager.currentAudioDeviceName, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                    
                    Spacer(minLength: 8)
                    
                    AnimatablePercentageText(progress: animatedVolumeProgress, isTopTitle: true, color: .primary, isPluggedIn: false, customText: "%d%")
                }
                .padding(.horizontal, 16 + 4 + 3) // 16 + trackPadding + innerPadding
            },
            expandedContent: {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(currentDevices, id: \.id) { device in
                            DeviceRowView(
                                device: device,
                                isCurrent: isPreview ? (device.id == 2) : device.name == mediaKeyManager.currentAudioDeviceName,
                                onSelect: {
                                    if !isPreview {
                                        VolumeManager.shared.setOutputDevice(id: device.id)
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                            isExpanded = false
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.top, 2)
                    .padding(.bottom, 8)
                    .padding(.horizontal, 4 + 3 + 4)
                }
            }
        )
        .frame(width: 260, height: isExpanded ? 56 + listHeight : 56, alignment: .top)
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(20)
        .onHoverExact { hovering in
            isHovering = hovering
            if !isPreview {
                mediaKeyManager.keepAlive(for: "volume", isHovering: hovering || isExpanded)
            }
        }
        .onChange(of: isExpanded) { expanded in
            if expanded {
                expandedKeepAliveTimer?.invalidate()
                expandedKeepAliveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    DispatchQueue.main.async {
                        if !isPreview { mediaKeyManager.keepAlive(for: "volume", isHovering: true) }
                    }
                }
            } else {
                expandedKeepAliveTimer?.invalidate()
                expandedKeepAliveTimer = nil
                if !isPreview {
                    mediaKeyManager.keepAlive(for: "volume", isHovering: isHovering)
                }
            }
        }
        .applyTheme(mediaKeyManager.overlayTheme)
        .onAppear {
            if isPreview {
                animatedVolumeProgress = 0.2
                withAnimation(.easeInOut(duration: 1.0)) {
                    animatedVolumeProgress = 0.65
                }
            } else {
                let targetProgress = CGFloat(actualVolume) / 100.0
                animatedVolumeProgress = targetProgress
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    animatedVolumeProgress = targetProgress
                }
            }
        }
        .onChange(of: actualVolume) { newValue in
            let targetProgress = CGFloat(newValue) / 100.0
            withAnimation(.easeOut(duration: 0.25)) {
                animatedVolumeProgress = targetProgress
            }
        }
        .onChange(of: actualIsMuted) { _ in
            let targetProgress = CGFloat(actualVolume) / 100.0
            withAnimation(.easeOut(duration: 0.25)) {
                animatedVolumeProgress = targetProgress
            }
        }
        .onChange(of: mediaKeyManager.audioDevicesChanged) { _ in
            if isExpanded {
                availableDevices = VolumeManager.shared.getAvailableOutputDevices()
            }
        }
        .onDisappear {
            expandedKeepAliveTimer?.invalidate()
            expandedKeepAliveTimer = nil
            mediaKeyManager.keepAlive(for: "volume", isHovering: false)
        }
    }
}

struct DeviceRowView: View {
    let device: (id: UInt32, name: String)
    let isCurrent: Bool
    var tintColor: Color = .blue
    let onSelect: () -> Void
    @State private var isHovering: Bool = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(device.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer()
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(tintColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovering ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .transition(.identity)
        .onHoverExact { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovering = hovering }
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

struct BrightnessOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("brightnessFillCenter") private var brightnessFillCenter: Bool = true
    @State private var animatedBrightnessProgress: CGFloat = 0.0
    @State private var isDragging: Bool = false
    @State private var holdTimer: Timer? = nil
    var isPreview: Bool = false
    
    private var actualBrightness: Int {
        isPreview ? 75 : mediaKeyManager.currentBrightness
    }
    
    private var iconName: String {
        if actualBrightness == 0 {
            return "sun.min"
        } else if actualBrightness < 33 {
            return "sun.min.fill"
        } else if actualBrightness < 66 {
            return "sun.max"
        } else {
            return "sun.max.fill"
        }
    }
    
    var body: some View {
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: .constant(false),
            showProgressBar: true,
            progress: animatedBrightnessProgress,
            barColor: .yellow,
            fillCenter: brightnessFillCenter,
            isMuted: false,
            listHeight: 0,
            supportDragGesture: true,
            onDrag: { v in
                mediaKeyManager.setBrightness(to: Int(v * 100))
            },
            baseContent: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 24)
                    
                    Text("Display")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer(minLength: 8)
                    
                    AnimatablePercentageText(progress: animatedBrightnessProgress, isTopTitle: true, color: .primary, isPluggedIn: false, customText: "%d%")
                }
                .padding(.horizontal, 16 + 4 + 3)
            },
            expandedContent: {
                EmptyView()
            }
        )
        .frame(width: 260, height: 56, alignment: .top)
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(20)
        .onHoverExact { hovering in
            if !isPreview {
                mediaKeyManager.keepAlive(for: "brightness", isHovering: hovering)
            }
        }
        .applyTheme(mediaKeyManager.overlayTheme)
        .onAppear {
            if isPreview {
                animatedBrightnessProgress = 0.1
                withAnimation(.easeInOut(duration: 1.2)) {
                    animatedBrightnessProgress = 0.8
                }
            } else {
                let targetProgress = CGFloat(actualBrightness) / 100.0
                animatedBrightnessProgress = targetProgress
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    animatedBrightnessProgress = targetProgress
                }
            }
        }
        .onChange(of: actualBrightness) { newValue in
            let targetProgress = CGFloat(newValue) / 100.0
            withAnimation(.easeOut(duration: 0.25)) {
                animatedBrightnessProgress = targetProgress
            }
        }
    }
}

struct CopyOverlayView: View {
    @State private var isHovering: Bool = false
    @State private var isExpanded: Bool = false
    @State private var expandedKeepAliveTimer: Timer? = nil
    
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    var isPreview: Bool = false
    var previewAction: String? = nil
    
    private var actualAction: String {
        previewAction ?? mediaKeyManager.clipboardAction
    }
    
    private var actionColor: Color {
        switch actualAction {
        case "copy": return .blue
        case "cut": return .orange
        case "paste": return .green
        default: return .blue
        }
    }
    
    private var actionIcon: String {
        switch actualAction {
        case "copy": return "doc.on.clipboard.fill"
        case "cut": return "scissors"
        case "paste": return "list.clipboard.fill"
        default: return "doc.on.clipboard.fill"
        }
    }
    
    private var actionTitle: String {
        switch actualAction {
        case "copy": return "Copied to Clipboard"
        case "cut": return "Cut to Clipboard"
        case "paste": return "Pasted from Clipboard"
        default: return "Copied to Clipboard"
        }
    }
    
    private var actionFallbackText: String {
        switch actualAction {
        case "copy": return "Item Copied"
        case "cut": return "Item Cut"
        case "paste": return "Item Pasted"
        default: return "Item Copied"
        }
    }
    
    private func calculatedTextHeight(for text: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: 174, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(rect.height)
    }
    
    var body: some View {
        let displayedText = isPreview ? "1 cup all-purpose flour\n2 tablespoons sugar\n2 teaspoons baking powder\n1 cup milk\n1 egg" : (mediaKeyManager.copiedText.isEmpty ? actionFallbackText : mediaKeyManager.copiedText)
        let reqHeight = calculatedTextHeight(for: displayedText)
        let canExpand = reqHeight > 22
        let listHeight = min(reqHeight, 250)
        
        let trackWidth: CGFloat = 260 - 8 // width - 2*trackPadding
        let copyPos = UserDefaults.standard.string(forKey: "copyOverlayPosition") ?? "bottom"
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            progress: 1.0,
            customProgressMask: AnyView(
                TimeoutProgressBar(trackWidth: trackWidth, isHovering: isHovering || isExpanded, initialDuration: MediaKeyManager.notificationDuration, hoverOutDuration: MediaKeyManager.notificationDuration)
                    .id(mediaKeyManager.clipboardEventId)
            ),
            barColor: actionColor,
            fillCenter: false, // The original uses strokeBorder
            isMuted: false,
            listHeight: listHeight,
            supportDragGesture: false,
            onSimpleTap: {
                if canExpand {
                    // UniversalOverlayView will automatically toggle isExpanded
                } else {
                    isExpanded = false
                }
                if !isPreview {
                    mediaKeyManager.keepAlive(for: "copy", isHovering: true)
                }
            },
            isExpandable: canExpand,
            expandUpwards: copyPos == "bottom",
            baseContent: {
                HStack(alignment: .top, spacing: 0) {
                    Image(systemName: actionIcon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 24)
                        .padding(.leading, 16)
                        .padding(.top, 4)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(actionTitle)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.leading, 14)
                            .padding(.trailing, 16)
                        
                        if !(isExpanded && canExpand) {
                            Text(displayedText)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .padding(.leading, 14)
                                .padding(.trailing, 16)
                        } else {
                            // Leave space so layout doesn't shift vertically if we want, but since it's aligned top, it's fine.
                            Color.clear.frame(height: 16)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 5)
            },
            expandedContent: {
                if canExpand {
                    ScrollView(showsIndicators: true) {
                        Text(displayedText)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 16 + 26 + 14) // icon padding + icon width + text padding
                            .padding(.trailing, 16)
                            .padding(.bottom, 6)
                    }
                    .padding(.top, -16)
                } else {
                    EmptyView()
                }
            }
        )
        .frame(width: 260, height: (isExpanded && canExpand) ? 56 + listHeight : 56, alignment: .top)
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(20)
        .onHoverExact { hovering in
            isHovering = hovering
            if !isPreview {
                mediaKeyManager.keepAlive(for: "copy", isHovering: hovering || isExpanded)
            }
        }
        .onChange(of: isExpanded) { expanded in
            if expanded {
                expandedKeepAliveTimer?.invalidate()
                expandedKeepAliveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    DispatchQueue.main.async {
                        if !isPreview { mediaKeyManager.keepAlive(for: "copy", isHovering: true) }
                    }
                }
            } else {
                expandedKeepAliveTimer?.invalidate()
                expandedKeepAliveTimer = nil
                if !isPreview {
                    mediaKeyManager.keepAlive(for: "copy", isHovering: isHovering)
                }
            }
        }
        .applyTheme(mediaKeyManager.overlayTheme)
    }
}

struct CapsLockOverlayView: View {
    @State private var isHovering: Bool = false
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    var isPreview: Bool = false
    var previewIsOn: Bool = true
    @State private var localPreviewIsOn: Bool = true
    
    private var actualIsOn: Bool {
        isPreview ? localPreviewIsOn : mediaKeyManager.isCapsLockOn
    }
    
    private var actionColor: Color {
        actualIsOn ? .green : .secondary
    }
    
    private var actionTitle: String {
        actualIsOn ? "Caps Lock ON" : "Caps Lock OFF"
    }
    
    var body: some View {
        let actionTitle = actualIsOn ? "Caps Lock ON" : "Caps Lock OFF"
        let actionColor: Color = actualIsOn ? .green : .secondary
        let trackWidth: CGFloat = 230 - 8 // width - 2*trackPadding
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: .constant(false),
            showProgressBar: true,
            progress: 1.0,
            customProgressMask: AnyView(
                TimeoutProgressBar(trackWidth: trackWidth, isHovering: isHovering, initialDuration: MediaKeyManager.notificationDuration, hoverOutDuration: MediaKeyManager.notificationDuration)
                    .id(mediaKeyManager.capsLockEventId)
            ),
            barColor: actionColor,
            fillCenter: false, // It was using strokeBorder
            isMuted: false,
            listHeight: 0,
            customWidth: 230,
            supportDragGesture: false,
            onSimpleTap: {
                if isPreview {
                    withAnimation { localPreviewIsOn.toggle() }
                } else {
                    mediaKeyManager.toggleCapsLock()
                }
            },
            baseContent: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: actualIsOn ? "capslock.fill" : "capslock")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Keyboard")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            
                        MarqueeText(text: actionTitle, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                    }
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16 + 4 + 3)
            },
            expandedContent: {
                EmptyView()
            }
        )
        .frame(width: 230, height: 56, alignment: .top)
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(20)
        .onHoverExact { hovering in
            if !isPreview {
                self.isHovering = hovering
                mediaKeyManager.keepAlive(for: "capsLock", isHovering: hovering)
            }
        }
        .onAppear {
            localPreviewIsOn = previewIsOn
        }
        .applyTheme(mediaKeyManager.overlayTheme)
    }
}


struct ThemeOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering: Bool = false
    
    var isPreview: Bool = false
    var previewIsDark: Bool = false
    
    var body: some View {
        let titleText: String
        let iconName: String
        let iconColor: Color
        
        if isPreview {
            if previewIsDark {
                titleText = "Dark Theme"
                iconName = "moon.fill"
                iconColor = .indigo
            } else {
                titleText = "Light Theme"
                iconName = "sun.max.fill"
                iconColor = .orange
            }
        } else {
            if mediaKeyManager.isDarkMode {
                titleText = "Dark Mode"
                iconName = "moon.fill"
                iconColor = .indigo
            } else {
                titleText = "Light Mode"
                iconName = "sun.max.fill"
                iconColor = .orange
            }
        }

        let trackWidth: CGFloat = 230 - 8 // width - 2*trackPadding
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: .constant(false),
            showProgressBar: true,
            progress: 1.0,
            customProgressMask: AnyView(
                TimeoutProgressBar(trackWidth: trackWidth, isHovering: isHovering, initialDuration: MediaKeyManager.notificationDuration, hoverOutDuration: MediaKeyManager.notificationDuration)
                    .id(mediaKeyManager.themeEventId)
            ),
            barColor: iconColor,
            fillCenter: false, // uses strokeBorder in original
            isMuted: false,
            listHeight: 0,
            customWidth: 230,
            supportDragGesture: false,
            baseContent: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Theme")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        MarqueeText(text: titleText, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                    }
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16 + 4 + 3)
            },
            expandedContent: {
                EmptyView()
            }
        )
        .frame(width: 230, height: 56, alignment: .top)
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(20)
        .onHoverExact { hovering in
            if !isPreview {
                self.isHovering = hovering
                mediaKeyManager.keepAlive(for: "theme", isHovering: hovering)
            }
        }
        .applyTheme(mediaKeyManager.overlayTheme)
        .simultaneousGesture(TapGesture().onEnded {
            if !isPreview {
                toggleSystemTheme()
            }
        })
    }
    
    private func toggleSystemTheme() {
        DispatchQueue.global(qos: .userInitiated).async {
            let scriptSource = """
            tell application "System Events"
                tell appearance preferences
                    set dark mode to not dark mode
                end tell
            end tell
            """
            if let script = NSAppleScript(source: scriptSource) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
                if let error = error {
                    print("Failed to toggle theme: \(error)")
                }
            }
        }
    }
}

struct PeripheralOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @State private var isHovering: Bool = false
    @State private var isExpanded: Bool = false
    
    var isPreview: Bool = false
    var previewIsConnected: Bool = false
    var notification: DeviceNotification?
    
    var isConnected: Bool {
        if isPreview { return previewIsConnected }
        if let notif = notification {
            return notif.isConnected
        }
        return mediaKeyManager.peripheralIsConnected
    }
    
    var deviceName: String {
        if isPreview { return "Magic Mouse" }
        if let notif = notification {
            return notif.deviceName
        }
        return mediaKeyManager.peripheralDeviceName
    }
    
    var iconName: String {
        if isPreview { return "magicmouse.fill" }
        if let notif = notification {
            return notif.icon
        }
        return mediaKeyManager.peripheralDeviceIcon
    }
    
    var body: some View {
        let actionColor: Color = isConnected ? .green : .red
        let trackWidth: CGFloat = 260 - 8 // width - 2*trackPadding
        let periPos = UserDefaults.standard.string(forKey: "peripheralOverlayPosition") ?? "bottom"
        
        let hasDetails = notification?.details?.isEmpty == false
        let isDrive = notification?.type == "USB Drive" || notification?.type == "USB Device"
        let isExpandable = isConnected && (hasDetails || isDrive)
        
        var calcHeight: CGFloat = 0
        if isExpandable {
            calcHeight += 1 // Divider
            if hasDetails {
                calcHeight += 12 // Spacing before details
                let count = CGFloat(notification?.details?.count ?? 0)
                calcHeight += (count * 16) + (max(count - 1, 0) * 8) // 16 per row + 8 spacing
            }
            if isDrive {
                calcHeight += 12 // Spacing before buttons
                calcHeight += 46 // buttons: 4 top, 30 content, 12 bottom
            } else if hasDetails {
                calcHeight += 12 // Spacing before clear frame
                calcHeight += 4 // clear frame
            }
        }
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            progress: 1.0,
            customProgressMask: AnyView(
                TimeoutProgressBar(trackWidth: trackWidth, isHovering: isHovering, initialDuration: MediaKeyManager.notificationDuration, hoverOutDuration: MediaKeyManager.notificationDuration)
                    .id(notification?.timestamp ?? Date(timeIntervalSince1970: 0))
            ),
            barColor: actionColor,
            fillCenter: false, // uses strokeBorder
            isMuted: false,
            listHeight: calcHeight,
            customWidth: 260,
            supportDragGesture: false,
            isExpandable: isExpandable,
            expandUpwards: periPos == "bottom",
            baseContent: {
                HStack(alignment: .top, spacing: 0) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isConnected ? .primary : .secondary)
                        .frame(width: 26, height: 24)
                        .padding(.leading, 16)
                        .padding(.top, 4)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isConnected ? "Connected" : "Disconnected")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.leading, 14)
                            .padding(.trailing, 16)
                        
                        MarqueeText(text: deviceName, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                            .padding(.leading, 14)
                            .padding(.trailing, 16)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 5)
            },
            expandedContent: {
                if isExpandable {
                    VStack(spacing: 12) {
                        let periPos = UserDefaults.standard.string(forKey: "peripheralOverlayPosition") ?? "bottom"
                        if periPos != "bottom" {
                            Divider()
                                .padding(.horizontal, 16)
                                .opacity(0.5)
                        }
                        
                        if let details = notification?.details, !details.isEmpty {
                            VStack(spacing: 8) {
                                ForEach(details.sorted(by: { $0.key > $1.key }), id: \.key) { key, value in
                                    HStack(alignment: .center) {
                                        Text(key)
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundColor(.secondary)
                                            .frame(width: 85, alignment: .leading)
                                        
                                        Spacer(minLength: 4)
                                        
                                        Text(value)
                                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                        
                        if isDrive {
                            HStack(spacing: 8) {
                                Button(action: {
                                    if !isPreview {
                                        mediaKeyManager.openDrive(named: deviceName)
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "folder")
                                        Text("Open in Finder")
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.primary.opacity(0.1))
                                    .cornerRadius(28 - 4 - 3)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    if !isPreview {
                                        mediaKeyManager.ejectDrive(named: deviceName)
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "eject")
                                        Text("Eject")
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.primary.opacity(0.1))
                                    .cornerRadius(28 - 4 - 3)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                            .padding(.top, 4)
                        } else if hasDetails {
                            Color.clear.frame(height: 4)
                        }
                        
                        if periPos == "bottom" {
                            Divider()
                                .padding(.horizontal, 16)
                                .opacity(0.5)
                        }
                    }
                } else {
                    EmptyView()
                }
            }
        )
        .frame(width: 260, height: (isExpanded && isExpandable) ? 56 + calcHeight : 56, alignment: .top)
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(20)
        .onChange(of: isExpanded) { expanded in
            if !isPreview {
                let keepAliveType = notification != nil ? "peripheral_\(notification!.id)" : "peripheral"
                mediaKeyManager.keepAlive(for: keepAliveType, isHovering: isHovering || expanded)
            }
        }
        .onHoverExact { hovering in
            if !isPreview {
                self.isHovering = hovering
                let keepAliveType = notification != nil ? "peripheral_\(notification!.id)" : "peripheral"
                mediaKeyManager.keepAlive(for: keepAliveType, isHovering: hovering || isExpanded)
            }
        }
        .onChange(of: notification?.isConnected) { connected in
            if connected == false {
                isExpanded = false
            }
        }
        .applyTheme(mediaKeyManager.overlayTheme)
    }
}

struct ConditionalGlassEffect: ViewModifier {
    var isActive: Bool
    func body(content: Content) -> some View {
        content.background(
            Color.clear.background(isActive ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.thinMaterial))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.glassBorder, lineWidth: 1))
        )
    }
}
