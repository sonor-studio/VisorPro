import SwiftUI

// MARK: - System Glass Background Modifier
/// Applies Apple's native glassEffect(.regular) to the system capsule, exactly matching Liquid Glass.
/// In Design Studio preview, provides a gentle native blur backing to match live appearance without HUD heaviness.
struct SystemGlassBackgroundModifier: ViewModifier {
    var isPreview: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @State private var renderNonce = UUID()
    
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: Capsule())
                .materialActiveAppearance(.active)
                .environment(\.controlActiveState, .key)
                .id(renderNonce)
                .task {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    renderNonce = UUID()
                }
        } else {
            content
                .background(.regularMaterial, in: Capsule())
        }
    }
}

// MARK: - Universal System Overlay View
/// A faithful replica of Apple's native macOS system pill OSD.
/// For Volume, Display Brightness, and Keyboard Brightness, provides the 16-segmented tick marks HUD.
/// For Status modules (Focus / Do Not Disturb, Caps Lock, Mic, Battery, Wi-Fi, Bluetooth), provides the 2-line status pill.
/// Supports hover persistence (prevents auto-dismissal while hovered), close button dismissal, and trackpad swipe dismissal.
struct UniversalSystemOverlayView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    
    var isPreview: Bool = false
    var icon: String? = nil
    var title: String? = nil
    var subtitle: String? = nil
    var progress: Double = 0.0
    var showProgressBar: Bool = false
    var isTimeoutMode: Bool = false
    var barColor: Color = .blue
    var isMuted: Bool = false
    var customWidth: CGFloat = 210
    var customHeight: CGFloat = 48
    var allowCloseButton: Bool = true
    var keepAliveId: String? = nil
    
    // Right action button (e.g. undo / return, play/pause, disconnect, theme toggle, caps lock toggle)
    var rightButtonIcon: String? = nil
    var rightButtonColor: Color = .blue
    var onRightButtonTap: (() -> Void)? = nil
    
    // Right status ring (e.g. battery percentage, disk space)
    var rightRingValue: Int? = nil
    var rightRingProgress: Double? = nil
    var rightRingColor: Color? = nil
    
    // Trailing app icon (e.g. Mic / Camera client bundle icon)
    var rightAppBundleId: String? = nil
    
    // Custom accessory trio (Left, Case, Right) for AirPods & multi-battery accessories
    var rightAirPodsTrio: (left: Int?, leftCharging: Bool, caseBat: Int?, caseCharging: Bool, right: Int?, rightCharging: Bool)? = nil
    
    // Interactive dragging / tapping for sliders
    var onDrag: ((CGFloat) -> Void)? = nil
    var onLeftTap: (() -> Void)? = nil
    
    @State private var isHovering: Bool = false
    @State private var hasLanded: Bool = false
    @State private var isCloseButtonHovered: Bool = false
    @State private var isRightButtonHovered: Bool = false
    
    @AppStorage("enableCloseButton") private var enableCloseButton: Bool = true
    @AppStorage("closeButtonOnRight") private var closeButtonOnRight: Bool = false
    @AppStorage("enableBouncyExpansion") private var enableBouncyExpansion: Bool = true
    
    private var hasTrailingItem: Bool {
        (rightButtonIcon != nil && onRightButtonTap != nil) || (rightRingValue != nil) || (rightAppBundleId != nil)
    }
    
    // Determine whether this overlay displays the 16-segmented slider (Volume, Brightness, Keyboard)
    // or a status pill with Title + Subtitle (Focus, Caps Lock, Mic, Battery, WiFi, Bluetooth, Media, etc.)
    private var isSliderMode: Bool {
        if isTimeoutMode { return false }
        if let id = keepAliveId {
            if id.contains("volume") || id.contains("brightness") || id.contains("keyboard") {
                return true
            }
        }
        if let icon = icon {
            if icon.contains("speaker") || icon.contains("sun") || icon.contains("keyboard") || icon.contains("display") {
                return true
            }
        }
        return false
    }
    
    private var sliderIconName: String {
        if let icon = icon, !icon.isEmpty {
            if icon.contains("speaker") {
                if isMuted || clampedProgress < 0.01 {
                    return "speaker.slash"
                } else if clampedProgress < 0.33 {
                    return "speaker.wave.1"
                } else if clampedProgress < 0.66 {
                    return "speaker.wave.2"
                } else {
                    return "speaker.wave.3"
                }
            } else if icon.contains("sun") || icon.contains("display") {
                return "sun.max"
            } else if icon.contains("keyboard") {
                return "keyboard"
            }
            return icon.replacingOccurrences(of: ".fill", with: "")
        }
        return "speaker.wave.3"
    }
    
    private var primaryColor: Color {
        colorScheme == .dark ? Color(white: 0.96) : Color(white: 0.12)
    }
    
    private var secondaryColor: Color {
        colorScheme == .dark ? Color(white: 0.94).opacity(0.72) : Color(white: 0.16).opacity(0.68)
    }
    
    private var activeSliderColor: Color {
        colorScheme == .dark ? Color(white: 0.94) : Color(white: 0.18)
    }
    
    private var inactiveTrackColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }
    
    private var effectiveIconColor: Color {
        if isMuted {
            return colorScheme == .dark ? Color(white: 0.94).opacity(0.45) : Color(white: 0.16).opacity(0.45)
        }
        if keepAliveId == "focus" {
            return Color(red: 0.48, green: 0.38, blue: 1.0) // Apple Focus vibrant purple
        }
        return primaryColor
    }
    
    private var clampedProgress: CGFloat {
        CGFloat(max(0.0, min(1.0, progress)))
    }
    
    private func triggerKeepAlive(hoveringOverride: Bool? = nil) {
        guard let id = keepAliveId, !isPreview else { return }
        let shouldKeepAlive = hoveringOverride ?? isHovering
        DispatchQueue.main.async {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                mediaKeyManager.keepAlive(for: id, isHovering: shouldKeepAlive)
                mediaKeyManager.setActualHover(for: id, isHovering: shouldKeepAlive)
            }
        }
    }
    
    var body: some View {
        UniversalGlassContainer {
            Group {
                if isSliderMode {
                // MARK: 16-Segmented Continuous Slider Bar (Native macOS Volume, Brightness & Keyboard HUD)
                // When hovered, transforms smoothly into an interactive native Slider, matching native macOS behavior.
                let trackWidth: CGFloat = 214.5
                let trackHeight: CGFloat = 4.0
                
                HStack(spacing: 16) {
                    Button {
                        onLeftTap?()
                    } label: {
                        Image(systemName: sliderIconName)
                            .font(.system(size: 21, weight: .regular))
                            .foregroundColor(primaryColor)
                            .frame(width: 26, height: 26, alignment: .center)
                    }
                    .buttonStyle(.plain)
                    .conditionalPointingHandCursor(isEnabled: onLeftTap != nil && !isPreview)
                    .padding(.leading, 19)
                    
                    ZStack(alignment: .leading) {
                        if isHovering {
                            // Native macOS SwiftUI Slider (same as used in microphone & corner settings)
                            Slider(
                                value: Binding(
                                    get: { Double(clampedProgress) },
                                    set: { newVal in
                                        let cgVal = CGFloat(newVal)
                                        onDrag?(cgVal)
                                        triggerKeepAlive(hoveringOverride: true)
                                    }
                                ),
                                in: 0...1
                            )
                            .tint(primaryColor)
                            .accentColor(primaryColor)
                            .environment(\.controlActiveState, .active)
                            .conditionalPointingHandCursor(isEnabled: !isPreview)
                            .frame(width: trackWidth)
                        } else {
                            // One continuous bar interrupted by vertical slits (16 discrete segments)
                            HStack(spacing: 1.5) {
                                let totalSteps = 16
                                let activeSteps: Int = {
                                    if isMuted || clampedProgress < 0.001 { return 0 }
                                    let steps = Int(round(clampedProgress * Double(totalSteps)))
                                    return max(1, min(totalSteps, steps))
                                }()
                                let activeColor = activeSliderColor
                                let inactiveColor = inactiveTrackColor
                                
                                ForEach(0..<totalSteps, id: \.self) { step in
                                    Rectangle()
                                        .fill(step < activeSteps ? activeColor : inactiveColor)
                                        .frame(width: 12.0, height: 4.0)
                                }
                            }
                            .frame(width: trackWidth, height: trackHeight)
                            .clipShape(Capsule())
                        }
                    }
                    .frame(width: trackWidth, height: trackHeight)
                    .padding(.trailing, 22)
                }
                .frame(width: 308, height: 64)
            } else {
                // MARK: Status Pill Mode (Focus, Caps Lock, Mic, Battery, Wi-Fi, Bluetooth, Accessories, Media, Theme)
                ZStack {
                    // Centered Title & Subtitle OR AirPods Battery Trio
                    VStack(alignment: .center, spacing: 2) {
                        if let title = title, !title.isEmpty {
                            MarqueeText(
                                text: title,
                                font: .system(size: 13, weight: .bold, design: .default),
                                foregroundColor: primaryColor,
                                alignment: .center
                            )
                            .lineLimit(1)
                        }
                        
                        if let trio = rightAirPodsTrio {
                            HStack(spacing: 8) {
                                if let lb = trio.left, lb > 0 {
                                    airpodsMiniBadge(icon: "airpodpro.left", pct: lb, isCharging: trio.leftCharging)
                                }
                                if let cb = trio.caseBat, cb > 0 {
                                    airpodsMiniBadge(icon: "airpodspro.chargingcase.wireless.fill", pct: cb, isCharging: trio.caseCharging)
                                }
                                if let rb = trio.right, rb > 0 {
                                    airpodsMiniBadge(icon: "airpodpro.right", pct: rb, isCharging: trio.rightCharging)
                                }
                            }
                            .padding(.top, 1)
                        } else if let subtitle = subtitle, !subtitle.isEmpty {
                            MarqueeText(
                                text: subtitle,
                                font: .system(size: 11, weight: .medium, design: .default),
                                foregroundColor: secondaryColor,
                                alignment: .center
                            )
                            .lineLimit(1)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .padding(.leading, (rightAirPodsTrio != nil) ? 44 : 50)
                    .padding(.trailing, (rightAirPodsTrio != nil) ? 20 : ((rightButtonIcon != nil || rightRingValue != nil || rightAppBundleId != nil) ? 52 : 36))
                    
                    // Left-pinned icon
                    HStack {
                        if let icon = icon, !icon.isEmpty {
                            Image(systemName: icon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(effectiveIconColor)
                                .frame(width: 24, height: 24, alignment: .center)
                                .padding(.leading, 16)
                        }
                        Spacer()
                    }
                    
                    // Right-pinned Action Button OR Status Ring OR App Icon
                    HStack {
                        Spacer()
                        if let btnIcon = rightButtonIcon, let action = onRightButtonTap {
                            Button {
                                action()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.12))
                                        .frame(width: 28, height: 28)
                                    
                                    Image(systemName: btnIcon)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(primaryColor)
                                }
                                .contentShape(Circle())
                                .scaleEffect(isRightButtonHovered ? 1.05 : 1.0)
                            }
                            .buttonStyle(.plain)
                            .onHover { h in
                                isRightButtonHovered = h
                                if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                            }
                            .padding(.trailing, 14)
                        } else if let ringVal = rightRingValue {
                            let prog = rightRingProgress ?? (Double(ringVal) / 100.0)
                            let ringCol = rightRingColor ?? (prog <= 0.20 ? .red : (prog <= 0.50 ? .yellow : .green))
                            
                            ZStack {
                                // Background track ring matching the volume & brightness inactive bar
                                Circle()
                                    .stroke(inactiveTrackColor, lineWidth: 3.2)
                                
                                // Progress arc
                                Circle()
                                    .trim(from: 0, to: CGFloat(min(max(prog, 0.0), 1.0)))
                                    .stroke(ringCol, style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                
                                // Centered number with %
                                Text("\(ringVal)%")
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                    .foregroundColor(primaryColor)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(width: 34, height: 34)
                            .padding(.trailing, 14)
                        } else if let bundleId = rightAppBundleId, !bundleId.isEmpty {
                            CachedAppIconView(
                                path: bundleId,
                                fallbackSystemName: "app.fill",
                                fallbackColor: .offStateGray,
                                size: 28
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6.5, style: .continuous))
                            .padding(.trailing, 14)
                        }
                    }
                }
                .frame(
                    width: customWidth,
                    height: customHeight
                )
            }
        }
        // MARK: Native Liquid Glass Material
        .modifier(SystemGlassBackgroundModifier(isPreview: isPreview))
        // MARK: Glass Specular Rim (Top-to-Bottom Highlight)
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: colorScheme == .dark ? [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.05)
                        ] : [
                            Color.white.opacity(0.40),
                            Color.black.opacity(0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.0
                )
                .allowsHitTesting(false)
        )
        // MARK: Drop Shadow
        .background(
            ZStack {
                Capsule()
                    .fill(Color.black)
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.15), radius: 10, y: 4)
                
                Capsule()
                    .fill(Color.black)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
        )
        // MARK: Close Button (Appears on Hover when enabled in settings)
        .overlay(alignment: .topLeading) {
            let width = isSliderMode ? 308 : customWidth
            let baseHeight: CGFloat = isSliderMode ? 64 : customHeight
            let dynamicOffset: CGFloat = -2
            // On larger overlays (height >= 56 pt, like volume / brightness / keyboard 64 pt),
            // inset slightly further into the curve so the button sits nicely balanced 50% on/off the rim.
            let edgeInset: CGFloat = (baseHeight >= 56 || width > 260) ? 14.0 : 8.0
            let buttonCenter = CGPoint(
                x: closeButtonOnRight ? width - edgeInset : edgeInset,
                y: dynamicOffset + 10
            )
            
            if enableCloseButton && allowCloseButton && isHovering {
                Button {
                    if isPreview {
                        NotificationCenter.default.post(name: NSNotification.Name("PreviewDismissTriggered"), object: nil)
                    } else if let id = keepAliveId {
                        MediaKeyManager.shared.forceHide(overlayId: id)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.85) : Color.black.opacity(0.70))
                        .frame(width: 20, height: 20)
                        .modifier(LiquidGlassCircleModifier(isPreview: isPreview))
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.10), radius: 2.5, x: 0, y: 1)
                        .scaleEffect(isCloseButtonHovered ? 1.08 : 1.0)
                }
                .buttonStyle(.plain)
                .onHover { h in
                    isCloseButtonHovered = h
                    if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                .offset(x: buttonCenter.x - 10, y: dynamicOffset)
                .transition(.scale.combined(with: .opacity))
            }
        }
        }
        // MARK: Hover Tracking for Timeout Persistence & Gestures
        .onHoverExact { hovering in
            let anim = enableBouncyExpansion ? Animation.spring(response: 0.38, dampingFraction: 0.65) : Animation.easeInOut(duration: 0.22)
            withAnimation(anim) {
                isHovering = hovering
            }
            triggerKeepAlive(hoveringOverride: hovering)
        }
        .onAppear {
            hasLanded = true
        }
    }
    
    @ViewBuilder
    private func airpodsMiniBadge(icon: String, pct: Int, isCharging: Bool) -> some View {
        HStack(spacing: 2) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(primaryColor)
                
                if isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(.green)
                        .offset(x: 3.5, y: 2)
                }
            }
            .frame(height: 14)
            
            Text("\(pct)%")
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundColor(pct <= 20 ? .red : (pct <= 50 ? .yellow : primaryColor))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}
