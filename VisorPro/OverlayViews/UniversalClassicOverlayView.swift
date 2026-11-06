import SwiftUI

// MARK: - Classic OS X HUD Bezel Overlay View
/// A pixel-exact reproduction of Apple's iconic classic OS X / macOS HUD Bezel (OSDUIHelper).
/// Specifications:
/// - Bezel: 200 × 200 pt, corner radius 18 pt, near-black at 62 % opacity over hudWindow blur.
/// - Position: Centred horizontally; bottom edge 140 pt above the display's bottom.
/// - Glyph centre: exactly 84 pt below the bezel's top.
/// - Level Bar: 16 segments, 9 pt wide, 1 pt apart, 6 pt tall, exactly 160 pt below the bezel's top on a darker track.
/// - Non-level / status bezels: No bottom bar; icon and content are placed dead-center in the 200 × 200 bezel.
struct UniversalClassicOverlayView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    
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
    var isWarning: Bool = false
    var customWidth: CGFloat = 200
    var customHeight: CGFloat = 200
    var customCornerRadius: CGFloat? = nil
    var allowCloseButton: Bool = true
    var keepAliveId: String? = nil
    var supportDragGesture: Bool = false
    var onDrag: ((CGFloat) -> Void)? = nil
    var onLeftTap: (() -> Void)? = nil
    var onSimpleTap: (() -> Void)? = nil
    var baseContent: (() -> AnyView)? = nil
    
    @State private var isHovering: Bool = false
    @State private var isCloseButtonHovered: Bool = false
    @State private var isDraggingSlider: Bool = false
    @State private var dragProgress: CGFloat? = nil
    
    @AppStorage("enableCloseButton") private var enableCloseButton = true
    @AppStorage("closeButtonOnRight") private var closeButtonOnRight = false
    
    private var isLightMode: Bool {
        if mediaKeyManager.overlayTheme == "light" {
            return true
        } else if mediaKeyManager.overlayTheme == "dark" {
            return false
        }
        return colorScheme == .light
    }
    /// Only overlays with actual continuous level adjustments (Volume, Brightness, Keyboard, Display)
    /// display the 16-segment level bar. Status overlays (Caps Lock, Trash, WiFi, etc.) have no bottom bar.
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
    
    private var clampedProgress: CGFloat {
        if let drag = dragProgress {
            return max(0.0, min(1.0, drag))
        }
        return CGFloat(max(0.0, min(1.0, progress)))
    }
    
    private var sliderIconName: String {
        if let id = keepAliveId, id.contains("keyboard") {
            return "lightbulb.fill"
        }
        if let icon = icon, !icon.isEmpty {
            if icon.contains("speaker") {
                if isMuted || clampedProgress < 0.01 {
                    return "speaker.slash.fill"
                } else if clampedProgress < 0.33 {
                    return "speaker.wave.1.fill"
                } else if clampedProgress < 0.66 {
                    return "speaker.wave.2.fill"
                } else {
                    return "speaker.wave.3.fill"
                }
            } else if icon.contains("sun") || icon.contains("display") {
                if clampedProgress < 0.01 {
                    return "sun.min"
                } else if clampedProgress < 0.33 {
                    return "sun.min.fill"
                } else if clampedProgress < 0.66 {
                    return "sun.max"
                } else {
                    return "sun.max.fill"
                }
            } else if icon.contains("keyboard") || icon.contains("lightbulb") {
                return "lightbulb.fill"
            }
            return icon
        }
        return isMuted ? "speaker.slash.fill" : "speaker.wave.3.fill"
    }
    
    /// Apple's exact bezel corner radius is rigidly fixed to 18 pt (never affected by multiplier slider).
    private var cornerRadius: CGFloat {
        18.0
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
        let isSurvey = keepAliveId == "survey"
        let isAirPodsGroup = keepAliveId == "airpodsGroupBattery"
        let w: CGFloat = (isSurvey || isAirPodsGroup) ? 260 : 200
        let h: CGFloat = isSurvey ? customHeight : (isAirPodsGroup ? 140 : 200)
        let r = cornerRadius
        let light = isLightMode
        let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
        
        ZStack {
            // MARK: Authentic Native Material Blur (No glassEffect)
            // .ultraThinMaterial provides rich translucency and strong blur without any artificial thick glass borders
            shape
                .fill(.ultraThinMaterial)
            
            // Subtle tint for classic contrast
            shape
                .fill(
                    light
                        ? Color.white.opacity(0.15)
                        : Color.black.opacity(0.25)
                )
            
            // MARK: Flat Classic Bezel Outline (Thin 0.5 pt rim without thick glowing specular rims)
            shape
                .strokeBorder(
                    light
                        ? Color.black.opacity(0.08)
                        : Color.white.opacity(0.12),
                    lineWidth: 0.5
                )
            
            // MARK: Content
            if (isSurvey || isAirPodsGroup), let content = baseContent {
                content()
                    .padding(12)
            } else if isSliderMode {
                levelBezelBody
            } else {
                statusBezelBody
            }
        }
        .frame(width: w, height: h)
        // MARK: Close Button (Positioned on the corner, protruding outward)
        .overlay(alignment: .topLeading) {
            if enableCloseButton && allowCloseButton && isHovering {
                closeButtonOverlay(width: w)
            }
        }
        // MARK: Expanded Compositing Drop Shadow
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .fill(Color.black)
                    .frame(width: w, height: h)
                    .shadow(
                        color: light ? Color.black.opacity(0.22) : Color.black.opacity(0.40),
                        radius: light ? 18 : 20,
                        x: 0,
                        y: light ? 6 : 8
                    )
                
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .fill(Color.black)
                    .frame(width: w, height: h)
                    .blendMode(.destinationOut)
            }
            .frame(width: w + 90, height: h + 90)
            .compositingGroup()
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                isHovering = hovering
            }
            triggerKeepAlive(hoveringOverride: hovering)
        }
    }
    
    // MARK: - Level Bezel Body (Volume, Brightness, Keyboard)
    /// Exact Apple specs:
    /// - Glyph centre: 84 pt below bezel's top.
    /// - 16 segments: 9 pt wide, 1 pt apart, 6 pt tall, located 160 pt below bezel's top on a darker track.
    @ViewBuilder
    private var levelBezelBody: some View {
        let totalBlocks = 16
        let blockWidth: CGFloat = 9.0
        let blockHeight: CGFloat = 6.0
        let blockSpacing: CGFloat = 1.0
        let trackWidth: CGFloat = CGFloat(totalBlocks) * blockWidth + CGFloat(totalBlocks - 1) * blockSpacing // 159.0 pt
        
        let activeCount: Int = {
            if isMuted || clampedProgress < 0.005 { return 0 }
            let count = Int(round(clampedProgress * CGFloat(totalBlocks)))
            return max(1, min(totalBlocks, count))
        }()
        
        let light = isLightMode
        let glyphColor = light ? Color(white: 0.22) : (isMuted ? Color.white.opacity(0.55) : Color.white.opacity(0.96))
        let glyphShadowColor = light ? Color.clear : Color.black.opacity(0.30)
        let glyphShadowY: CGFloat = 1.0
        
        ZStack {
            // Glyph: centred horizontally, glyph centre exactly 84 pt below bezel's top
            Button {
                onLeftTap?()
            } label: {
                Image(systemName: sliderIconName)
                    .font(.system(size: 68, weight: .regular))
                    .foregroundColor(glyphColor)
                    .shadow(color: glyphShadowColor, radius: light ? 0 : 1, x: 0, y: glyphShadowY)
                    .frame(width: 76, height: 76, alignment: .center)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .conditionalPointingHandCursor(isEnabled: onLeftTap != nil && !isPreview)
            .position(x: 100, y: 84)
            
            // 16-Segment Level Bar: centred horizontally, exactly 160 pt below bezel's top
            ZStack {
                // Background track behind segments
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(light ? Color.black.opacity(0.12) : Color.black.opacity(0.35))
                    .frame(width: trackWidth + 4, height: blockHeight + 3)
                
                HStack(spacing: blockSpacing) {
                    ForEach(0..<totalBlocks, id: \.self) { index in
                        let isActive = index < activeCount
                        let activeBlockColor = light ? Color(white: 0.22) : Color.white
                        let inactiveBlockColor = light ? Color.black.opacity(0.10) : Color.white.opacity(0.18)
                        RoundedRectangle(cornerRadius: 1.0)
                            .fill(isActive ? activeBlockColor : inactiveBlockColor)
                            .frame(width: blockWidth, height: blockHeight)
                    }
                }
            }
            .frame(width: trackWidth, height: 20)
            .contentShape(Rectangle())
            .conditionalPointingHandCursor(isEnabled: supportDragGesture && !isPreview)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard supportDragGesture else { return }
                        isDraggingSlider = true
                        let localX = value.location.x
                        let newProgress = max(0.0, min(1.0, localX / trackWidth))
                        dragProgress = newProgress
                        onDrag?(newProgress)
                        triggerKeepAlive(hoveringOverride: true)
                    }
                    .onEnded { value in
                        guard supportDragGesture else { return }
                        let localX = value.location.x
                        let newProgress = max(0.0, min(1.0, localX / trackWidth))
                        dragProgress = nil
                        isDraggingSlider = false
                        onDrag?(newProgress)
                        triggerKeepAlive()
                    }
            )
            .position(x: 100, y: 160)
        }
        .frame(width: 200, height: 200)
    }
    
    // MARK: - Status Bezel Body (Caps Lock, Trash, WiFi, Bluetooth, Mic, etc.)
    /// Non-level overlays have NO bottom bar ("opaska na dole").
    /// The icon and content are placed dead-center in the 200 × 200 bezel.
    @ViewBuilder
    private var statusBezelBody: some View {
        let light = isLightMode
        let iconColor = light ? Color(white: 0.22) : Color.white.opacity(0.96)
        let iconShadowColor = light ? Color.clear : Color.black.opacity(0.30)
        let titleColor = light ? Color(white: 0.12) : Color.white.opacity(0.96)
        let subtitleColor = light ? Color(white: 0.20) : Color.white.opacity(0.75)
        
        VStack(spacing: 10) {
            Spacer(minLength: 0)
            
            if let icon = icon, !icon.isEmpty {
                Button {
                    onLeftTap?() ?? onSimpleTap?()
                } label: {
                    Image(systemName: icon)
                        .font(.system(size: 72, weight: .regular))
                        .foregroundColor(iconColor)
                        .shadow(color: iconShadowColor, radius: light ? 0 : 1, x: 0, y: light ? 0 : 1)
                        .frame(width: 86, height: 80, alignment: .center)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .conditionalPointingHandCursor(isEnabled: (onLeftTap != nil || onSimpleTap != nil) && !isPreview)
            }
            
            VStack(spacing: 3) {
                if let title = title, !title.isEmpty {
                    MarqueeText(
                        text: title,
                        font: .system(size: 17, weight: .semibold, design: .default),
                        foregroundColor: titleColor,
                        alignment: .center
                    )
                    .lineLimit(1)
                }
                
                if let subtitle = subtitle, !subtitle.isEmpty {
                    MarqueeText(
                        text: subtitle,
                        font: .system(size: 13, weight: .regular, design: .default),
                        foregroundColor: subtitleColor,
                        alignment: .center
                    )
                    .lineLimit(1)
                }
                
                if let tertiaryText = tertiaryText, !tertiaryText.isEmpty {
                    MarqueeText(
                        text: tertiaryText,
                        font: .system(size: 11.5, weight: .semibold, design: .default),
                        foregroundColor: subtitleColor.opacity(0.85),
                        alignment: .center
                    )
                    .lineLimit(1)
                }
            }
            .padding(.horizontal, 18)
            
            Spacer(minLength: 0)
        }
        .frame(width: 200, height: 200)
    }
    
    // MARK: - Close Button Overlay (Corner Protruding)
    @ViewBuilder
    private func closeButtonOverlay(width: CGFloat) -> some View {
        let light = isLightMode
        let edgeInset: CGFloat = 8.0
        let buttonCenter = CGPoint(
            x: closeButtonOnRight ? width - edgeInset : edgeInset,
            y: -2 + 10
        )
        
        Button {
            if isPreview {
                NotificationCenter.default.post(name: NSNotification.Name("PreviewDismissTriggered"), object: nil)
            } else if let id = keepAliveId {
                MediaKeyManager.shared.forceHide(overlayId: id)
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundColor(light ? Color.black.opacity(0.65) : Color.white.opacity(0.85))
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(light ? Color.white.opacity(0.15) : Color.black.opacity(0.25))
                )
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            light ? Color.black.opacity(0.12) : Color.white.opacity(0.18),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: Color.black.opacity(light ? 0.15 : 0.35), radius: 2.0, x: 0, y: 1)
                .scaleEffect(isCloseButtonHovered ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { h in
            isCloseButtonHovered = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .offset(x: buttonCenter.x - 10, y: -2)
        .transition(.scale.combined(with: .opacity))
    }
}
