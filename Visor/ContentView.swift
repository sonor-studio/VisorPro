import SwiftUI

struct ContentView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager

    @AppStorage("volumeOverlayPosition") private var volumeOverlayPosition: String = "bottom"
    @AppStorage("batteryOverlayPosition") private var batteryOverlayPosition: String = "top"
    @AppStorage("brightnessOverlayPosition") private var brightnessOverlayPosition: String = "top"
    @AppStorage("copyOverlayPosition") private var copyOverlayPosition: String = "bottom"
    @AppStorage("capsLockOverlayPosition") private var capsLockOverlayPosition: String = "bottom"
    @State private var overlayWindow: NSWindow?
    
    enum OverlayType: String, CaseIterable {
        case volume, brightness, battery, copy, capsLock, bluetooth, language, media, theme, mic, camera, wifi, peripheral
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
        if showBattery { active.append(ActiveOverlay(id: "battery", type: .battery, position: batteryOverlayPosition, notification: nil)) }
        if mediaKeyManager.showCopyIndicator { active.append(ActiveOverlay(id: "copy", type: .copy, position: copyOverlayPosition, notification: nil)) }
        if mediaKeyManager.showCapsLockIndicator { active.append(ActiveOverlay(id: "capsLock", type: .capsLock, position: capsLockOverlayPosition, notification: nil)) }
        
        let btPos = UserDefaults.standard.string(forKey: "bluetoothOverlayPosition") ?? "bottom"
        for notif in mediaKeyManager.activeBluetoothNotifications {
            active.append(ActiveOverlay(id: "bluetooth_\(notif.id)", type: .bluetooth, position: btPos, notification: notif))
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
    
    private func yPos(for position: String, in geo: GeometryProxy) -> CGFloat {
        let padding: CGFloat = 40
        let pillHeight: CGFloat = 56
        if position == "top" { return padding + (pillHeight / 2) }
        if position == "center" { return geo.size.height / 2 }
        return geo.size.height - padding - (pillHeight / 2)
    }

    private func xPos(for position: String, index: Int, total: Int, in geo: GeometryProxy) -> CGFloat {
        let averageWidth: CGFloat = 260
        let spacing: CGFloat = 24
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
    
    var body: some View {
        let showBattery = mediaKeyManager.showChargingStatus || mediaKeyManager.showLowBatteryWarning
        let showVolume = mediaKeyManager.showVolumeIndicator
        let showBrightness = mediaKeyManager.showBrightnessIndicator
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
        
        let isVisible = showBattery || showVolume || showBrightness || showCopy || showCapsLock || showBluetooth || showLanguage || showMedia || showTheme || showMic || showCamera || showWiFi || showPeripheral
        
        let btPos = UserDefaults.standard.string(forKey: "bluetoothOverlayPosition") ?? "bottom"
        let langPos = UserDefaults.standard.string(forKey: "languageOverlayPosition") ?? "bottom"
        let mediaPos = UserDefaults.standard.string(forKey: "mediaOverlayPosition") ?? "bottom"
        let themePos = UserDefaults.standard.string(forKey: "themeOverlayPosition") ?? "bottom"
        let micPos = UserDefaults.standard.string(forKey: "micOverlayPosition") ?? "top"
        let camPos = UserDefaults.standard.string(forKey: "cameraOverlayPosition") ?? "top"
        let wifiPos = UserDefaults.standard.string(forKey: "wifiOverlayPosition") ?? "bottom"
        let periPos = UserDefaults.standard.string(forKey: "peripheralOverlayPosition") ?? "bottom"
        
        GeometryReader { geo in
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
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onChange(of: isVisible) { _, visible in
            if visible {
                repositionWindow()
            }
        }
        .background(WindowAccessor(window: $overlayWindow))
        .onChange(of: overlayWindow) { _, window in
            if let window = window {
                window.isOpaque = false
                window.backgroundColor = .clear
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.styleMask.remove(.titled)
                window.hasShadow = false
                window.level = .screenSaver
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
                window.isMovableByWindowBackground = false
                window.ignoresMouseEvents = true
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
    @State private var animatedBatteryProgress: CGFloat = 0.0
    @State private var isPulsing: Bool = false
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
        let isDischarging = !actualIsPluggedIn
        
        if isDischarging {
            // Time until empty
            let totalMinutesLeft = Int(Double(percentage) * 3.5) // Simulation: 3.5 mins per percent
            let hours = totalMinutesLeft / 60
            let minutes = totalMinutesLeft % 60
            
            if isWarningMode {
                return "\(totalMinutesLeft) mins remaining"
            }
            
            if hours > 0 {
                return "About \(hours)h \(minutes)m remaining"
            } else {
                return "About \(minutes)m remaining"
            }
        } else {
            // Time until full charge
            let remainingPercent = 100 - percentage
            let totalMinutesLeft = Int(Double(remainingPercent) * 1.5) // Simulation: 1.5 mins per percent
            let hours = totalMinutesLeft / 60
            let minutes = totalMinutesLeft % 60
            
            if hours > 0 {
                return "About \(hours)h \(minutes)m to full"
            } else {
                return "About \(minutes)m to full"
            }
        }
    }
    
    var body: some View {
        let width: CGFloat = 260
        let height: CGFloat = 56
        let trackPadding: CGFloat = 4
        let innerPadding: CGFloat = 3
        
        let trackWidth = width - (trackPadding * 2)
        let trackHeight = height - (trackPadding * 2)
        let innerWidth = trackWidth - (innerPadding * 2)
        let innerHeight = trackHeight - (innerPadding * 2)
        
        ZStack(alignment: .leading) {
            // WARSTWA 1: Baza
            ZStack {
                ActiveVisualEffectView()
                    .clipShape(Capsule())
                
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: innerPadding)
                    .frame(width: trackWidth, height: trackHeight)
            }
            .frame(width: width, height: height)
            
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
            .glassEffect(.thinMaterial, in: Capsule())
            .padding(.leading, trackPadding + innerPadding)
            
            // WTYCZKA (Na samej górze, nad szkłem, czysty kolor batteryColor)
            if !isWarningMode && actualIsPluggedIn {
                Image(systemName: "powerplug.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .padding(.bottom, 1.0) // Delikatniejsze przesunięcie!
                    .foregroundColor(batteryColor)
                    .brightness(-0.1) // Sztuczne obniżenie jasności "na ślepo", by wyrównać odczucie kolorów
                    .modifier(PlugIconMover(
                        progress: animatedBatteryProgress,
                        targetProgress: CGFloat(actualPercentage) / 100.0,
                        width: trackWidth - innerPadding,
                        height: trackHeight - innerPadding
                    ))
            }
        }
        .frame(width: width, height: height)
        .contentShape(Capsule())
        .onHover { isHovering in
            if !isPreview {
                mediaKeyManager.keepAlive(for: "battery", isHovering: isHovering)
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
                
                // Dla trybu ostrzegawczego wydłużamy czas do 2.2s i spłaszczamy krzywą
                let actualDuration = isWarningMode ? 2.2 : (3.5 * Double(distance))
                
                let animation: Animation
                if isWarningMode {
                    animation = .timingCurve(0.2, 0.8, 0.3, 1.0, duration: actualDuration)
                } else {
                    animation = .easeOut(duration: max(0.1, actualDuration))
                }
                
                withAnimation(animation) {
                    animatedBatteryProgress = targetProgress
                }
                if isWarningMode {
                    isPulsing = true
                }
            }
        }
        .onChange(of: actualPercentage) { newValue in
            let targetProgress = CGFloat(newValue) / 100.0
            let distance = abs(animatedBatteryProgress - targetProgress)
            let dynamicDuration = 3.5 * Double(distance)
            
            withAnimation(.easeOut(duration: max(0.1, dynamicDuration))) {
                animatedBatteryProgress = targetProgress
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
    
    var body: some View {
        let width: CGFloat = 260
        let height: CGFloat = 56
        let trackPadding: CGFloat = 4
        let innerPadding: CGFloat = 3
        
        let trackWidth = width - (trackPadding * 2)
        let trackHeight = height - (trackPadding * 2)
        let innerWidth = trackWidth - (innerPadding * 2)
        let innerHeight = trackHeight - (innerPadding * 2)
        
        // Nie używamy już fillWidth z `max()`, żeby wartości były proporcjonalne od 0 do 100%
        
        ZStack(alignment: .leading) {
            // WARSTWA 1: Baza (Szkło + grubsza szara ramka)
            ZStack {
                ActiveVisualEffectView()
                    .clipShape(Capsule())
                
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: innerPadding)
                    .frame(width: trackWidth, height: trackHeight)
            }
            .frame(width: width, height: height)
            
            // WARSTWA 2: Niebieski pasek postępu (Kapsuła przycięta maską dla proporcji)
            Group {
                if volumeFillCenter {
                    Capsule()
                        .fill(actualIsMuted ? Color.secondary.opacity(0.7) : Color.blue.opacity(0.85))
                } else {
                    Capsule()
                        .strokeBorder(actualIsMuted ? Color.secondary.opacity(0.7) : Color.blue.opacity(0.85), lineWidth: innerPadding)
                }
            }
            .frame(width: trackWidth, height: trackHeight)
            .mask(
                HStack(spacing: 0) {
                    Rectangle()
                        .frame(width: max(0, trackWidth * animatedVolumeProgress))
                    Spacer(minLength: 0)
                }
            )
            .padding(.leading, trackPadding)
            
            // WARSTWA 3: Górna warstwa (Glass Blur z informacjami)
            HStack(alignment: .center, spacing: 14) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(actualIsMuted ? .secondary : .primary)
                        .frame(width: 26, height: 24)
                    
                    MarqueeText(text: actualIsMuted ? "Muted" : mediaKeyManager.currentAudioDeviceName, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                    
                    Spacer(minLength: 8)
                    
                    AnimatablePercentageText(progress: animatedVolumeProgress, isTopTitle: true, color: .primary, isPluggedIn: false, customText: "%d%")
                }
                .padding(.horizontal, 16)
                .frame(width: innerWidth, height: innerHeight)
                .modifier(ConditionalGlassEffect(isActive: !volumeFillCenter))
            .padding(.leading, trackPadding + innerPadding)
        }
        .frame(width: width, height: height)
        .contentShape(Capsule())
        .onHover { isHovering in
            if !isPreview {
                mediaKeyManager.keepAlive(for: "volume", isHovering: isHovering)
            }
        }
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(20)
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
    }
}

struct BrightnessOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("brightnessFillCenter") private var brightnessFillCenter: Bool = true
    @State private var animatedBrightnessProgress: CGFloat = 0.0
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
        let width: CGFloat = 260
        let height: CGFloat = 56
        let trackPadding: CGFloat = 4
        let innerPadding: CGFloat = 3
        
        let trackWidth = width - (trackPadding * 2)
        let trackHeight = height - (trackPadding * 2)
        let innerWidth = trackWidth - (innerPadding * 2)
        let innerHeight = trackHeight - (innerPadding * 2)
        
        ZStack(alignment: .leading) {
            // WARSTWA 1: Baza (Szkło + grubsza szara ramka)
            ZStack {
                ActiveVisualEffectView()
                    .clipShape(Capsule())
                
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: innerPadding)
                    .frame(width: trackWidth, height: trackHeight)
            }
            .frame(width: width, height: height)
            
            // WARSTWA 2: Żółty pasek postępu (Kapsuła przycięta maską dla proporcji)
            Group {
                if brightnessFillCenter {
                    Capsule()
                        .fill(Color.yellow.opacity(0.85))
                } else {
                    Capsule()
                        .strokeBorder(Color.yellow.opacity(0.85), lineWidth: innerPadding)
                }
            }
            .frame(width: trackWidth, height: trackHeight)
            .mask(
                HStack(spacing: 0) {
                    Rectangle()
                        .frame(width: max(0, trackWidth * animatedBrightnessProgress))
                    Spacer(minLength: 0)
                }
            )
            .padding(.leading, trackPadding)
            
            // WARSTWA 3: Górna warstwa (Glass Blur z informacjami)
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
                .padding(.horizontal, 16)
                .frame(width: innerWidth, height: innerHeight)
                .modifier(ConditionalGlassEffect(isActive: !brightnessFillCenter))
            .padding(.leading, trackPadding + innerPadding)
        }
        .frame(width: width, height: height)
        .contentShape(Capsule())
        .onHover { isHovering in
            if !isPreview {
                mediaKeyManager.keepAlive(for: "brightness", isHovering: isHovering)
            }
        }
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(20)
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
    
    var body: some View {
        let width: CGFloat = 260
        let height: CGFloat = 56
        let trackPadding: CGFloat = 4
        let innerPadding: CGFloat = 3
        
        let trackWidth = width - (trackPadding * 2)
        let trackHeight = height - (trackPadding * 2)
        let innerWidth = trackWidth - (innerPadding * 2)
        let innerHeight = trackHeight - (innerPadding * 2)
        
        ZStack(alignment: .leading) {
            // WARSTWA 1: Baza (Szkło + grubsza szara ramka)
            ZStack {
                ActiveVisualEffectView()
                    .clipShape(Capsule())
                
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: innerPadding)
                    .frame(width: trackWidth, height: trackHeight)
            }
            .frame(width: width, height: height)
            
            // WARSTWA 2: Kolorowa ramka
            Capsule()
                .strokeBorder(actionColor.opacity(0.85), lineWidth: innerPadding)
                .frame(width: trackWidth, height: trackHeight)
                .mask(
                    HStack(spacing: 0) {
                        TimeoutProgressBar(trackWidth: trackWidth, isHovering: isHovering, initialDuration: MediaKeyManager.notificationDuration, hoverOutDuration: MediaKeyManager.notificationDuration)
                            .id(mediaKeyManager.clipboardEventId)
                        Spacer(minLength: 0)
                    }
                )
                .padding(.leading, trackPadding)
            
            // WARSTWA 3: Górna warstwa (Glass Blur z informacjami)
            HStack(alignment: .center, spacing: 14) {
                    Image(systemName: actionIcon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(actionTitle)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Text((isPreview || mediaKeyManager.copiedText.isEmpty) ? actionFallbackText : mediaKeyManager.copiedText)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16)
                .frame(width: innerWidth, height: innerHeight)
                .glassEffect(.thinMaterial, in: Capsule())
            .padding(.leading, trackPadding + innerPadding)
        }
        .frame(width: width, height: height)
        .contentShape(Capsule())
        .onHover { isHovering in
            if !isPreview {
                self.isHovering = isHovering
                mediaKeyManager.keepAlive(for: "copy", isHovering: isHovering)
            }
        }
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(20)
        .applyTheme(mediaKeyManager.overlayTheme)
    }
}

struct CapsLockOverlayView: View {
    @State private var isHovering: Bool = false
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    var isPreview: Bool = false
    var previewIsOn: Bool = true
    
    private var actualIsOn: Bool {
        isPreview ? previewIsOn : mediaKeyManager.isCapsLockOn
    }
    
    private var actionColor: Color {
        actualIsOn ? .green : .secondary
    }
    
    private var actionTitle: String {
        actualIsOn ? "Caps Lock ON" : "Caps Lock OFF"
    }
    
    var body: some View {
        let width: CGFloat = 200
        let height: CGFloat = 56
        let trackPadding: CGFloat = 4
        let innerPadding: CGFloat = 3
        
        let trackWidth = width - (trackPadding * 2)
        let trackHeight = height - (trackPadding * 2)
        let innerWidth = trackWidth - (innerPadding * 2)
        let innerHeight = trackHeight - (innerPadding * 2)
        
        ZStack(alignment: .leading) {
            ZStack {
                ActiveVisualEffectView()
                    .clipShape(Capsule())
                
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: innerPadding)
                    .frame(width: trackWidth, height: trackHeight)
            }
            .frame(width: width, height: height)
            
            Capsule()
                .strokeBorder(actionColor.opacity(0.85), lineWidth: innerPadding)
                .frame(width: trackWidth, height: trackHeight)
                .mask(
                    HStack(spacing: 0) {
                        TimeoutProgressBar(trackWidth: trackWidth, isHovering: isHovering, initialDuration: MediaKeyManager.notificationDuration, hoverOutDuration: MediaKeyManager.notificationDuration)
                            .id(mediaKeyManager.capsLockEventId)
                        Spacer(minLength: 0)
                    }
                )
                .padding(.leading, trackPadding)
            
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
                .padding(.horizontal, 16)
                .frame(width: innerWidth, height: innerHeight)
                .glassEffect(.thinMaterial, in: Capsule())
            .padding(.leading, trackPadding + innerPadding)
        }
        .frame(width: width, height: height)
        .contentShape(Capsule())
        .onHover { isHovering in
            if !isPreview {
                self.isHovering = isHovering
                mediaKeyManager.keepAlive(for: "capsLock", isHovering: isHovering)
            }
        }
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(20)
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
        let isDark = isPreview ? previewIsDark : (colorScheme == .dark)
        let iconName = isDark ? "moon.fill" : "sun.max.fill"
        let titleText = isDark ? "Ciemny" : "Jasny"
        let iconColor: Color = isDark ? .indigo : .yellow
        
        let width: CGFloat = 200
        let height: CGFloat = 56
        let trackPadding: CGFloat = 4
        let innerPadding: CGFloat = 3
        
        let trackWidth = width - (trackPadding * 2)
        let trackHeight = height - (trackPadding * 2)
        let innerWidth = trackWidth - (innerPadding * 2)
        let innerHeight = trackHeight - (innerPadding * 2)
        
        ZStack(alignment: .leading) {
            // WARSTWA 1: Baza
            ZStack {
                ActiveVisualEffectView()
                    .clipShape(Capsule())
                
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: innerPadding)
                    .frame(width: trackWidth, height: trackHeight)
            }
            .frame(width: width, height: height)
            
            // WARSTWA 2: Kolorowa ramka
            Capsule()
                .strokeBorder(iconColor.opacity(0.85), lineWidth: innerPadding)
                .frame(width: trackWidth, height: trackHeight)
                .mask(
                    HStack(spacing: 0) {
                        TimeoutProgressBar(trackWidth: trackWidth, isHovering: isHovering, initialDuration: MediaKeyManager.notificationDuration, hoverOutDuration: MediaKeyManager.notificationDuration)
                            .id(mediaKeyManager.themeEventId)
                        Spacer(minLength: 0)
                    }
                )
                .padding(.leading, trackPadding)
            
            // WARSTWA 3: Górna warstwa
            HStack(alignment: .center, spacing: 14) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Motyw")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        MarqueeText(text: titleText, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                    }
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16)
                .frame(width: innerWidth, height: innerHeight)
                .glassEffect(.thinMaterial, in: Capsule())
            .padding(.leading, trackPadding + innerPadding)
        }
        .frame(width: width, height: height)
        .contentShape(Capsule())
        .onHover { isHovering in
            if !isPreview {
                self.isHovering = isHovering
                mediaKeyManager.keepAlive(for: "theme", isHovering: isHovering)
            }
        }
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(20)
        .applyTheme(mediaKeyManager.overlayTheme)
    }
}

struct PeripheralOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @State private var isHovering: Bool = false
    
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
        
        let width: CGFloat = 260
        let height: CGFloat = 56
        let trackPadding: CGFloat = 4
        let innerPadding: CGFloat = 3
        
        let trackWidth = width - (trackPadding * 2)
        let trackHeight = height - (trackPadding * 2)
        let innerWidth = trackWidth - (innerPadding * 2)
        let innerHeight = trackHeight - (innerPadding * 2)
        
        ZStack(alignment: .leading) {
            // WARSTWA 1: Baza
            ZStack {
                ActiveVisualEffectView()
                    .clipShape(Capsule())
                
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: innerPadding)
                    .frame(width: trackWidth, height: trackHeight)
            }
            .frame(width: width, height: height)
            
            // WARSTWA 2: Kolorowa ramka
            Capsule()
                .strokeBorder(actionColor.opacity(0.85), lineWidth: innerPadding)
                .frame(width: trackWidth, height: trackHeight)
                .mask(
                    HStack(spacing: 0) {
                        TimeoutProgressBar(trackWidth: trackWidth, isHovering: isHovering, initialDuration: MediaKeyManager.notificationDuration, hoverOutDuration: MediaKeyManager.notificationDuration)
                            .id(notification?.timestamp ?? Date())
                        Spacer(minLength: 0)
                    }
                )
                .padding(.leading, trackPadding)
            
            // WARSTWA 3: Górna warstwa
            HStack(alignment: .center, spacing: 14) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isConnected ? "Połączono" : "Rozłączono")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        MarqueeText(text: deviceName, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                    }
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16)
                .frame(width: innerWidth, height: innerHeight)
                .glassEffect(.thinMaterial, in: Capsule())
            .padding(.leading, trackPadding + innerPadding)
        }
        .frame(width: width, height: height)
        .contentShape(Capsule())
        .onHover { isHovering in
            if !isPreview {
                self.isHovering = isHovering
                let keepAliveType = notification != nil ? "peripheral_\(notification!.id)" : "peripheral"
                mediaKeyManager.keepAlive(for: keepAliveType, isHovering: isHovering)
            }
        }
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(20)
        .applyTheme(mediaKeyManager.overlayTheme)
    }
}

struct ConditionalGlassEffect: ViewModifier {
    var isActive: Bool
    func body(content: Content) -> some View {
        if isActive {
            content.glassEffect(.thinMaterial, in: Capsule(), blendingMode: .behindWindow)
        } else {
            content.glassEffect(.thinMaterial, in: Capsule(), blendingMode: .withinWindow)
        }
    }
}

