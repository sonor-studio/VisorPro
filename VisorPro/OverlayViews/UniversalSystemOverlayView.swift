import SwiftUI

// MARK: - System Glass Background Modifier (macOS < 26 fallback)
/// Fallback material for macOS < 26 where GlassEffectContainer is not available.
/// On macOS 26+, the System overlay is wrapped directly in GlassEffectContainer
/// and the child uses .glassEffect(.clear) — this modifier is not applied there.
struct SystemGlassBackgroundModifier: ViewModifier {
    var isPreview: Bool = false
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(AlwaysActiveVisualEffectView(material: .popover, blendingMode: .behindWindow).clipShape(Capsule()))
    }
}

// MARK: - System Segmented Slider Bar
/// Continuous active bar masked by 16 discrete segments, allowing perfectly smooth sub-pixel sliding animations (e.g. smoothly sliding to 0 upon mute).
struct SystemSegmentedSliderBar: View, Animatable {
    var progress: CGFloat
    var activeColor: Color
    var inactiveColor: Color
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    var body: some View {
        let totalSteps = 16
        let trackWidth: CGFloat = 214.5
        let trackHeight: CGFloat = 4.0
        let activeWidth = max(0, min(trackWidth, trackWidth * progress))
        
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.black.opacity(0.35))
            Rectangle()
                .fill(inactiveColor)
            Rectangle()
                .fill(activeColor)
                .frame(width: activeWidth)
        }
        .frame(width: trackWidth, height: trackHeight)
        .mask(
            HStack(spacing: 1.5) {
                ForEach(0..<totalSteps, id: \.self) { _ in
                    Rectangle()
                        .frame(width: 12.0, height: trackHeight)
                }
            }
        )
        .clipShape(Capsule())
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
    @ObservedObject private var overlayState = OverlayStateRelay.shared
    
    var isPreview: Bool = false
    var icon: String? = nil
    var title: String? = nil
    var subtitle: String? = nil
    var tertiaryText: String? = nil
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
    @State private var systemSliderAnimatedProgress: CGFloat = 0.0
    
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
            if icon.contains("speaker") || icon.contains("sun.max") || icon.contains("keyboard") {
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
    
    // Theme resolution:
    // Slider overlays ALWAYS behave as dark (white text, dark clear glass) regardless of theme.
    // Regular status overlays follow the chosen theme (dark vs light), or the system appearance when set to "system".
    private var effectiveIsDark: Bool {
        if isSliderMode { return true }
        if mediaKeyManager.overlayTheme == "dark" { return true }
        if mediaKeyManager.overlayTheme == "light" { return false }
        return colorScheme == .dark
    }
    
    // Only sliders dynamically adapt their backing to wallpaper luminance:
    private var sliderBackingOpacity: Double {
        let lum = max(0.0, min(1.0, overlayState.backgroundLuminance))
        let sat = max(0.0, min(1.0, overlayState.backgroundSaturation))
        // Protect colorful backgrounds (sat >= 0.34) keeping them clean and translucent at 0.08.
        // For neutral bright backgrounds (sat <= 0.12), scale opacity aggressively up to 0.96 for deep black contrast.
        let satFactor = max(0.0, min(1.0, 1.0 - (sat - 0.12) / 0.22))
        let whiteness = max(0.0, min(1.0, (lum - 0.10) / 0.70)) * satFactor
        return 0.08 + (0.88 * pow(whiteness, 0.75))
    }
    
    private var primaryColor: Color {
        if isSliderMode {
            return Color.white
        }
        return effectiveIsDark ? Color.white : Color(white: 0.10)
    }
    
    private var secondaryColor: Color {
        if isSliderMode {
            return Color.white.opacity(0.80)
        }
        return effectiveIsDark ? Color.white.opacity(0.75) : Color(white: 0.18)
    }
    
    private var activeSliderColor: Color {
        Color.white
    }
    
    private var inactiveTrackColor: Color {
        if isSliderMode {
            return Color.white.opacity(0.25)
        }
        return effectiveIsDark ? Color.white.opacity(0.20) : Color.black.opacity(0.15)
    }
    
    private var effectiveIconColor: Color {
        if isMuted {
            return isSliderMode ? Color.white.opacity(0.45) : (effectiveIsDark ? Color.white.opacity(0.45) : Color(white: 0.12).opacity(0.45))
        }
        if keepAliveId == "focus" {
            return barColor
        }
        return primaryColor
    }
    
    private var clampedProgress: CGFloat {
        CGFloat(max(0.0, min(1.0, progress)))
    }
    
    private var effectiveSliderProgress: CGFloat {
        systemSliderAnimatedProgress
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
        if #available(macOS 26.0, *) {
            GlassEffectContainer {
                overlayContent
                    .background(
                        Capsule()
                            .fill(
                                isSliderMode
                                    ? Color.black.opacity(sliderBackingOpacity)
                                    : (effectiveIsDark ? Color.black.opacity(0.05) : Color.white.opacity(0.04))
                            )
                    )
                    .background(
                        Group {
                            if isSliderMode {
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .opacity(0.06)
                            }
                        }
                    )
                    .glassEffect(isSliderMode ? .clear : .regular, in: Capsule())
                    .overlay(capsuleRimOverlay)
                    .activeMaterialAppearanceIfAvailable()
                    .environment(\.controlActiveState, .key)
            }
            .activeMaterialAppearanceIfAvailable()
            .environment(\.controlActiveState, .key)
            .overlay(alignment: .topLeading) { closeButtonOverlay }
            .onHoverExact { hovering in
                let anim = enableBouncyExpansion ? Animation.spring(response: 0.38, dampingFraction: 0.65) : Animation.easeInOut(duration: 0.22)
                withAnimation(anim) { isHovering = hovering }
                triggerKeepAlive(hoveringOverride: hovering)
            }
            .onAppear { handleOnAppear() }
            .onChange(of: isMuted) { _, newMuted in handleMutedChange(newMuted) }
            .onChange(of: progress) { _, newProgress in handleProgressChange(newProgress) }
        } else {
            overlayContent
                .modifier(SystemGlassBackgroundModifier(isPreview: isPreview))
                .overlay(capsuleRimOverlay)
                .overlay(alignment: .topLeading) { closeButtonOverlay }
                .onHoverExact { hovering in
                    let anim = enableBouncyExpansion ? Animation.spring(response: 0.38, dampingFraction: 0.65) : Animation.easeInOut(duration: 0.22)
                    withAnimation(anim) { isHovering = hovering }
                    triggerKeepAlive(hoveringOverride: hovering)
                }
                .onAppear { handleOnAppear() }
                .onChange(of: isMuted) { _, newMuted in handleMutedChange(newMuted) }
                .onChange(of: progress) { _, newProgress in handleProgressChange(newProgress) }
        }
    }

    // MARK: - Shared sub-view helpers

    @ViewBuilder
    private var overlayContent: some View {
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
                                    get: { Double(effectiveSliderProgress) },
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
                            .environment(\.controlActiveState, .key)
                            .conditionalPointingHandCursor(isEnabled: !isPreview)
                            .frame(width: trackWidth)
                        } else {
                            // 16 discrete segments filled continuously with fluid animation down to 0
                            SystemSegmentedSliderBar(
                                progress: effectiveSliderProgress,
                                activeColor: activeSliderColor,
                                inactiveColor: inactiveTrackColor
                            )
                        }
                    }
                    .frame(width: trackWidth, height: trackHeight)
                    .padding(.trailing, 22)
                }
                .frame(width: 308, height: 64)
            } else {
                // MARK: Status Pill Mode (Focus, Caps Lock, Mic, Battery, Wi-Fi, Bluetooth, Accessories, Media, Theme)
                let hasTrailing = ((rightButtonIcon != nil && onRightButtonTap != nil) || rightRingValue != nil || rightAppBundleId != nil || rightAirPodsTrio != nil)
                let isSingleTitleOnly = (subtitle == nil || subtitle!.isEmpty) && !hasTrailing && rightAirPodsTrio == nil
                
                if isSingleTitleOnly {
                    // Cleanly centered unified badge [Icon + Title] for single-title pills (e.g. Date overlay)
                    HStack(alignment: .center, spacing: 9) {
                        if let icon = icon, !icon.isEmpty {
                            Image(systemName: icon)
                                .font(.system(size: 20, weight: .regular))
                                .foregroundColor(effectiveIconColor)
                                .frame(width: 22, height: 22, alignment: .center)
                        }
                        
                        if let title = title, !title.isEmpty {
                            Text(title)
                                .font(.system(size: 13, weight: .semibold, design: .default))
                                .foregroundColor(primaryColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .frame(
                        width: customWidth,
                        height: customHeight
                    )
                } else {
                    ZStack {
                        let contentMargin: CGFloat = 48.0
                        let contentLeading: CGFloat = (icon != nil && !icon!.isEmpty) ? contentMargin : 20.0
                        let contentTrailing: CGFloat = (hasTrailing || (icon != nil && !icon!.isEmpty)) ? contentMargin : 20.0
                        
                        // Centered Title & Subtitle OR AirPods Battery Trio
                        VStack(alignment: .center, spacing: 1.5) {
                            if let title = title, !title.isEmpty {
                                MarqueeText(
                                    text: title,
                                    font: .system(size: 12.5, weight: .semibold, design: .default),
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
                                let displaySubtitle = (tertiaryText != nil && !tertiaryText!.isEmpty) ? "\(tertiaryText!) • \(subtitle)" : subtitle
                                MarqueeText(
                                    text: displaySubtitle,
                                    font: .system(size: 11.5, weight: .regular, design: .default),
                                    foregroundColor: secondaryColor,
                                    alignment: .center
                                )
                                .lineLimit(1)
                            } else if let tertiaryText = tertiaryText, !tertiaryText.isEmpty {
                                MarqueeText(
                                    text: tertiaryText,
                                    font: .system(size: 11.5, weight: .regular, design: .default),
                                    foregroundColor: secondaryColor,
                                    alignment: .center
                                )
                                .lineLimit(1)
                            }
                        }
                        .multilineTextAlignment(.center)
                        .padding(.leading, contentLeading)
                        .padding(.trailing, contentTrailing)
                        
                        // Left-pinned icon
                        HStack {
                            if let icon = icon, !icon.isEmpty {
                                Image(systemName: icon)
                                    .font(.system(size: 24, weight: .regular))
                                    .foregroundColor(effectiveIconColor)
                                    .frame(width: 28, height: 28, alignment: .center)
                                    .padding(.leading, 15)
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
                            let ringCol = rightRingColor ?? Color.batteryLevelColor(forProgress: prog)
                            
                            ZStack {
                                // Background track ring matching the volume & brightness inactive bar
                                Circle()
                                    .stroke(inactiveTrackColor, lineWidth: 4.2)
                                
                                // Progress arc
                                Circle()
                                    .trim(from: 0, to: CGFloat(min(max(prog, 0.0), 1.0)))
                                    .stroke(ringCol, style: StrokeStyle(lineWidth: 4.2, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                
                                // Centered number (percentage symbol omitted for clean spacing)
                                Text("\(ringVal)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
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
    }
}

    // MARK: - Capsule rim specular highlight overlay
    @ViewBuilder
    private var capsuleRimOverlay: some View {
        Capsule()
            .strokeBorder(
                LinearGradient(
                    colors: (isSliderMode || effectiveIsDark) ? [
                        Color.white.opacity(0.30),
                        Color.white.opacity(0.08)
                    ] : [
                        Color.white.opacity(0.45),
                        Color.black.opacity(0.06)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1.0
            )
            .allowsHitTesting(false)
    }

    // MARK: - Close button overlay (appears on hover when enabled in settings)
    @ViewBuilder
    private var closeButtonOverlay: some View {
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
                    .foregroundColor((isSliderMode || effectiveIsDark) ? Color.white.opacity(0.85) : Color.black.opacity(0.70))
                    .frame(width: 20, height: 20)
                    .modifier(LiquidGlassCircleModifier(isPreview: isPreview, isClear: isSliderMode, isDark: effectiveIsDark))
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

    // MARK: - Lifecycle helpers (shared between macOS 26 and fallback paths)

    private func handleOnAppear() {
        hasLanded = true
        if isMuted {
            // If opening while muted, start at non-zero and slide down to 0
            systemSliderAnimatedProgress = clampedProgress > 0 ? clampedProgress : 0.5
            withAnimation(.easeOut(duration: 0.18)) {
                systemSliderAnimatedProgress = 0.0
            }
        } else {
            systemSliderAnimatedProgress = clampedProgress
        }
    }

    private func handleMutedChange(_ newMuted: Bool) {
        if newMuted {
            // Smoothly slide down to 0
            withAnimation(.easeOut(duration: 0.18)) {
                systemSliderAnimatedProgress = 0.0
            }
        } else {
            // Smoothly slide back up from 0 to current unmuted volume level
            systemSliderAnimatedProgress = 0.0
            withAnimation(.easeOut(duration: 0.18)) {
                systemSliderAnimatedProgress = clampedProgress
            }
        }
    }

    private func handleProgressChange(_ newProgress: Double) {
        if !isMuted {
            withAnimation(.easeOut(duration: 0.12)) {
                systemSliderAnimatedProgress = CGFloat(max(0.0, min(1.0, newProgress)))
            }
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
