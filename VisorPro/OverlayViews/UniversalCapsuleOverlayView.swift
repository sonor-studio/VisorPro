import SwiftUI

// MARK: - Tapered Bottom Capsule Track Shape
/// A custom shape representing the bottom contour of a capsule HUD.
/// It runs horizontally along the bottom edge with 0 gap/inset from the rim,
/// curving slightly into the bottom corners and tapering smoothly to a sharp point at the ends.
/// When the container expands, it stays anchored to the bottom edge.
struct TaperedBottomCapsuleTrack: Shape {
    var inset: CGFloat = 0.0
    var strokeWidth: CGFloat = 3.5
    var cornerRadius: CGFloat = 28.0
    var startAngle: Double = 132.0 // ~7:30-8:00 position (low in bottom-left corner)
    var endAngle: Double = 48.0   // ~4:00-4:30 position (low in bottom-right corner)
    
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        guard w > 20 && h > 10 else { return p }
        
        let r = min(cornerRadius, min(w / 2.0, h / 2.0))
        let effectiveR = max(0.1, r - inset)
        let innerR = max(0.1, effectiveR - strokeWidth)
        
        let centerL = CGPoint(x: r, y: h - r)
        let centerR = CGPoint(x: w - r, y: h - r)
        
        let radStart = startAngle * .pi / 180.0
        
        // Tip on the left:
        let tipL = CGPoint(
            x: centerL.x + effectiveR * CGFloat(cos(radStart)),
            y: centerL.y + effectiveR * CGFloat(sin(radStart))
        )
        
        // Move to left tip
        p.move(to: tipL)
        
        // 1. Left outer arc from startAngle (132°) down to 90° (decreasing angle -> clockwise: true)
        p.addArc(center: centerL, radius: effectiveR, startAngle: .degrees(startAngle), endAngle: .degrees(90), clockwise: true)
        
        // 2. Straight line across the bottom edge (touches very bottom: y = h - inset)
        p.addLine(to: CGPoint(x: w - r, y: h - inset))
        
        // 3. Right outer arc from 90° down to endAngle (48°) (decreasing angle -> clockwise: true)
        p.addArc(center: centerR, radius: effectiveR, startAngle: .degrees(90), endAngle: .degrees(endAngle), clockwise: true)
        
        // Turn around at tipR to draw inner contour tapering from 0.5 up to strokeWidth:
        let steps = 6
        for i in (0...steps).reversed() {
            let frac = CGFloat(i) / CGFloat(steps)
            let angleDeg = 48.0 + (72.0 - 48.0) * Double(frac)
            let rad = angleDeg * .pi / 180.0
            let currentThickness = 0.5 + (strokeWidth - 0.5) * frac
            let currentRadius = effectiveR - currentThickness
            p.addLine(to: CGPoint(
                x: centerR.x + currentRadius * CGFloat(cos(rad)),
                y: centerR.y + currentRadius * CGFloat(sin(rad))
            ))
        }
        
        // From 72° to 90° at full inner radius (increasing angle -> clockwise: false)
        p.addArc(center: centerR, radius: innerR, startAngle: .degrees(72), endAngle: .degrees(90), clockwise: false)
        
        // Bottom inner straight line back to left
        p.addLine(to: CGPoint(x: r, y: h - inset - strokeWidth))
        
        // From 90° to 108° on left at full inner radius (increasing angle -> clockwise: false)
        p.addArc(center: centerL, radius: innerR, startAngle: .degrees(90), endAngle: .degrees(108), clockwise: false)
        
        // From 108° to 132°, thickness tapers from strokeWidth down to 0.5 at tipL:
        for i in 0...steps {
            let frac = CGFloat(i) / CGFloat(steps)
            let angleDeg = 108.0 + (132.0 - 108.0) * Double(frac)
            let rad = angleDeg * .pi / 180.0
            let currentThickness = strokeWidth - (strokeWidth - 0.5) * frac
            let currentRadius = effectiveR - currentThickness
            p.addLine(to: CGPoint(
                x: centerL.x + currentRadius * CGFloat(cos(rad)),
                y: centerL.y + currentRadius * CGFloat(sin(rad))
            ))
        }
        
        p.closeSubpath()
        return p
    }
}

// MARK: - Liquid Glass Rim Overlay
/// A subtle specular glass rim. When isAround is false, it highlights the top and bottom edges while smoothly vanishing on the curved lateral sides.
/// When isAround is true, it provides a continuous crisp specular highlight around the entire perimeter.
/// The cutout notch area is completely excluded so no bright frame appears around the close button.
struct LiquidGlassRimOverlay: View {
    var shape: BendedCornerShape
    var bendProgress: CGFloat = 0.0
    var buttonCenter: CGPoint = .zero
    var cutoutSize: CGFloat = 12.0
    var isAround: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        shape
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.22 : 0.45),
                        Color.white.opacity(colorScheme == .dark ? 0.08 : 0.20)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1.0
            )
            .modifier(ConditionalRimMask(isAround: isAround))
            .allowsHitTesting(false)
    }
}

struct ConditionalRimMask: ViewModifier {
    var isAround: Bool
    func body(content: Content) -> some View {
        if isAround {
            content
        } else {
            content.mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .clear, location: 0.04),
                        .init(color: .black, location: 0.14),
                        .init(color: .black, location: 0.86),
                        .init(color: .clear, location: 0.96),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }
}

// MARK: - Liquid Glass Background Modifier
/// Applies Apple's native glassEffect to the dynamically bended container shape.
struct LiquidGlassBackgroundModifier: ViewModifier {
    var shape: BendedCornerShape
    var isPreview: Bool = false
    var isDark: Bool = true
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .background(
                    shape.fill(
                        isDark ? Color.black.opacity(0.05) : Color.white.opacity(0.04)
                    )
                )
                .glassEffect(.regular, in: shape)
                .materialActiveAppearance(.active)
                .environment(\.controlActiveState, .key)
        } else {
            content
                .background(.regularMaterial, in: shape)
        }
    }
}

// MARK: - Liquid Glass Circle Modifier (Close Button)
/// Applies Apple's native glassEffect to a circular shape, matching the main capsule overlay material.
struct LiquidGlassCircleModifier: ViewModifier {
    var isPreview: Bool = false
    var isDark: Bool = true
    var isClear: Bool = false
    var customBackingOpacity: Double? = nil
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .background(
                    Circle().fill(
                        isClear
                            ? Color.black.opacity(customBackingOpacity ?? (isDark ? 0.25 : 0.15))
                            : (isDark ? Color.black.opacity(0.05) : Color.white.opacity(0.04))
                    )
                )
                .background(
                    Group {
                        if isClear {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .opacity(0.06)
                        }
                    }
                )
                .glassEffect(isClear ? .clear : .regular, in: Circle())
                .materialActiveAppearance(.active)
                .environment(\.controlActiveState, .key)
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: isDark ? [
                                    Color.white.opacity(0.30),
                                    Color.white.opacity(0.08)
                                ] : [
                                    Color.white.opacity(0.45),
                                    Color.black.opacity(0.06)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.75
                        )
                )
        } else {
            content
                .background(.regularMaterial, in: Circle())
                .overlay(
                    Circle()
                        .strokeBorder(
                            Color.white.opacity(isDark ? 0.20 : 0.35),
                            lineWidth: 0.75
                        )
                )
        }
    }
}

// MARK: - Universal Capsule Overlay View (Liquid Glass)
/// A modern elongated capsule / pill overlay style using Apple's native glassEffect.
/// Features 100% behavioral parity with Default (gestures, zone taps, expansion, keep-alive on hover),
/// combined with Apple Liquid Glass material and an anchored bottom-contour progress gauge.
struct UniversalCapsuleOverlayView<BaseContent: View, ExpandedContent: View>: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.overlayForcedMinimal) private var overlayForcedMinimal
    
    @Binding var isExpanded: Bool
    var isPreview: Bool = false
    var isLarge: Bool = false
    var showProgressBar: Bool = false
    var isTimeoutMode: Bool = false
    var timeoutDuration: Double = 3.0
    var timeoutEventId: AnyHashable? = nil
    var progress: CGFloat = 0.0
    var barColor: Color = .blue
    var isMuted: Bool = false
    var forceGlow: Bool = false
    var customGlowOpacity: Double? = nil
    var customWidth: CGFloat = 260
    var customHeight: CGFloat = 56
    var customCornerRadius: CGFloat? = nil
    var supportDragGesture: Bool = false
    var onDrag: ((CGFloat) -> Void)? = nil
    var onLeftTap: (() -> Void)? = nil
    var onRightTap: (() -> Void)? = nil
    var onSimpleTap: (() -> Void)? = nil
    var isExpandable: Bool = true
    var expandUpwards: Bool = false
    var keepAliveId: String? = nil
    var fixedExpandedHeight: CGFloat? = nil
    var allowCloseButton: Bool = true
    var allowBaseHitTesting: Bool = false
    var minimalText: String? = nil
    var minimalIcon: String? = nil
    
    @ViewBuilder var baseContent: () -> BaseContent
    @ViewBuilder var expandedContent: () -> ExpandedContent
    
    @State private var isDragging: Bool = false
    @State private var isHovering: Bool = false
    @State private var expandedHeight: CGFloat = 0
    @State private var expandedKeepAliveTimer: Timer? = nil
    @State private var lastTapTime: TimeInterval = 0
    @State private var isMinimalExpandedByClick: Bool = false
    @State private var hasLanded: Bool = false
    @State private var bendProgress: CGFloat = 0.0
    @State private var isCloseButtonHovered: Bool = false
    
    @AppStorage("enableCloseButton") private var enableCloseButton = true
    @AppStorage("keepCloseButtonWhenExpanded") private var keepCloseButtonWhenExpanded = true
    @AppStorage("closeButtonOnRight") private var closeButtonOnRight = false
    @AppStorage("enableBouncyExpansion") private var enableBouncyExpansion = true
    @AppStorage("enableMinimalMode") private var enableMinimalMode = false
    
    private var isGloballyHovered: Bool {
        guard let keepAliveId = keepAliveId else { return isHovering }
        return isHovering || mediaKeyManager.globalHoveredTypes.contains(keepAliveId)
    }
    
    private var isEffectivelyMinimal: Bool {
        let minimalAllowed = overlayForcedMinimal ?? enableMinimalMode
        return minimalAllowed && !isMinimalExpandedByClick && !isHovering && !isExpanded
    }
    
    private var effectiveIsDark: Bool {
        if mediaKeyManager.overlayTheme == "dark" { return true }
        if mediaKeyManager.overlayTheme == "light" { return false }
        return colorScheme == .dark
    }
    
    private var effectiveWidth: CGFloat {
        isEffectivelyMinimal ? 140 : customWidth
    }
    
    private var effectiveBaseHeight: CGFloat {
        isEffectivelyMinimal ? 38 : customHeight
    }
    
    private var outerRadius: CGFloat {
        let baseRadius = effectiveBaseHeight / 2.0
        return isEffectivelyMinimal ? baseRadius : (customCornerRadius ?? (baseRadius * CGFloat(mediaKeyManager.cornerRoundingMultiplier)))
    }
    
    private var effectiveBarColor: Color {
        isMuted ? Color.offStateGray.opacity(0.95) : barColor.opacity(0.95)
    }
    
    private var clampedProgress: CGFloat {
        min(1.0, max(0.0, progress))
    }
    
    private var shouldShowGlow: Bool {
        if forceGlow { return true }
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        guard mediaKeyManager.enableGlowEffect && !premiumKey.isEmpty else { return false }
        
        let effectivelyExpanded = isExpanded || keepAliveId == "airpodsGroupBattery"
        if effectivelyExpanded && !mediaKeyManager.glowOnExpanded { return false }
        
        if mediaKeyManager.glowEffectTheme == "both" { return true }
        if mediaKeyManager.glowEffectTheme == "dark" && colorScheme == .dark { return true }
        if mediaKeyManager.glowEffectTheme == "light" && colorScheme == .light { return true }
        return false
    }
    
    private var shouldShowCloseButton: Bool {
        guard allowCloseButton else { return false }
        guard enableCloseButton && hasLanded else { return false }
        guard !isEffectivelyMinimal else { return false }
        if keepCloseButtonWhenExpanded {
            return isHovering || isExpanded
        } else {
            return isHovering
        }
    }
    
    private func triggerKeepAlive(hoveringOverride: Bool? = nil, expandedOverride: Bool? = nil) {
        if !isPreview, let keepAliveId = keepAliveId {
            let currentHover = hoveringOverride ?? isHovering
            let currentExpanded = expandedOverride ?? isExpanded
            DispatchQueue.main.async {
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    mediaKeyManager.keepAlive(for: keepAliveId, isHovering: currentHover || currentExpanded)
                    mediaKeyManager.setActualHover(for: keepAliveId, isHovering: currentHover)
                }
            }
        }
    }
    
    var body: some View {
        let width = effectiveWidth
        let baseHeight = effectiveBaseHeight
        let prog = clampedProgress
        let radius = outerRadius
        let dynamicOffset: CGFloat = -2
        // On larger overlays (height >= 56 pt, e.g. volume, brightness, media), inset slightly further into the curve so the button and cutout sit comfortably 50% on/off the rim
        let edgeInset: CGFloat = min(radius * 0.55, 17.0)
        let buttonCenter = CGPoint(
            x: closeButtonOnRight ? width - edgeInset : edgeInset,
            y: dynamicOffset + 10
        )
        let cutoutCenterForShape = CGPoint(x: closeButtonOnRight ? width - buttonCenter.x : buttonCenter.x, y: buttonCenter.y)
        let cutoutSize: CGFloat = 12
        let bendedShape = BendedCornerShape(
            radius: radius,
            bendAmount: bendProgress,
            absoluteCutoutCenter: cutoutCenterForShape,
            cutoutRadius: cutoutSize,
            frameOffset: .zero,
            isRightSide: closeButtonOnRight
        )
        
        VStack(spacing: 0) {
            // MARK: Top Section (Base Content + Interactive Tap/Drag Zones)
            ZStack(alignment: .center) {
                if (overlayForcedMinimal ?? enableMinimalMode) {
                    // Minimal mode content
                    HStack(spacing: 7) {
                        if let icon = minimalIcon, !icon.isEmpty {
                            Image(systemName: icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        Text(minimalText ?? "Visor")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .frame(width: 140, height: 38, alignment: .center)
                    .opacity(isEffectivelyMinimal ? 1.0 : 0.0)
                    .blur(radius: isEffectivelyMinimal ? 0.0 : 8.0)
                    .scaleEffect(isEffectivelyMinimal ? 1.0 : 0.88)
                    .allowsHitTesting(isEffectivelyMinimal)
                    
                    // Full base content
                    baseContent()
                        .frame(width: customWidth, height: customHeight, alignment: .center)
                        .allowsHitTesting(allowBaseHitTesting && !isEffectivelyMinimal)
                        .animation(nil, value: isExpanded)
                        .modifier(ConditionalDrawingGroup(enabled: !allowBaseHitTesting && !isEffectivelyMinimal))
                        .opacity(isEffectivelyMinimal ? 0.0 : 1.0)
                        .blur(radius: isEffectivelyMinimal ? 8.0 : 0.0)
                        .scaleEffect(isEffectivelyMinimal ? 0.92 : 1.0)
                } else {
                    baseContent()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .allowsHitTesting(allowBaseHitTesting)
                        .animation(nil, value: isExpanded)
                        .modifier(ConditionalDrawingGroup(enabled: !allowBaseHitTesting))
                }
                
                // Invisible Hit-Testing Zones (Exact match with default)
                HStack(spacing: 0) {
                    if !isEffectivelyMinimal && onLeftTap != nil {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 60)
                            .contentShape(Rectangle())
                            .conditionalPointingHandCursor(isEnabled: !isPreview)
                    }
                    if (!isExpandable && onSimpleTap != nil) || isExpandable || isEffectivelyMinimal {
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .conditionalPointingHandCursor(isEnabled: isExpandable || onSimpleTap != nil || isEffectivelyMinimal)
                    } else {
                        Spacer()
                    }
                    if !isEffectivelyMinimal && onRightTap != nil && !supportDragGesture {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 50)
                            .contentShape(Rectangle())
                            .conditionalPointingHandCursor(isEnabled: !isPreview)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .allowsHitTesting(!allowBaseHitTesting)
            }
            .frame(width: width, height: baseHeight, alignment: .center)
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        if supportDragGesture && !isEffectivelyMinimal {
                            if !isDragging { isDragging = true }
                            let v = max(0, min(1, value.location.x / width))
                            onDrag?(v)
                        }
                    }
                    .onEnded { _ in
                        if isDragging { isDragging = false }
                    }
            )
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { event in
                        if isDragging { return }
                        
                        let now = CACurrentMediaTime()
                        guard now - lastTapTime > 0.25 else { return }
                        lastTapTime = now
                        
                        if enableMinimalMode && isExpandable && !isMinimalExpandedByClick {
                            let anim: Animation = enableBouncyExpansion ? .spring(response: 0.4, dampingFraction: 0.6) : .easeInOut(duration: 0.25)
                            withAnimation(anim) {
                                isMinimalExpandedByClick = true
                                isExpanded = true
                            }
                            return
                        }
                        
                        let locX = event.location.x
                        
                        if onLeftTap != nil && locX <= 60 {
                            onLeftTap?()
                        } else if onRightTap != nil && !supportDragGesture && locX >= width - 50 {
                            onRightTap?()
                        } else {
                            if isExpandable {
                                let anim: Animation = !isExpanded ? (enableBouncyExpansion ? .spring(response: 0.4, dampingFraction: 0.6) : .easeInOut(duration: 0.25)) : .easeOut(duration: 0.2)
                                withAnimation(anim) {
                                    isExpanded.toggle()
                                    if !isExpanded {
                                        isMinimalExpandedByClick = false
                                    }
                                }
                            } else {
                                onSimpleTap?()
                            }
                        }
                    }
            )
            
            // MARK: Expanded Content Section
            expandedContent()
                .padding(.bottom, 16)
                .frame(width: width)
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    Group {
                        if fixedExpandedHeight == nil && isExpanded {
                            GeometryReader { proxy in
                                Color.clear.preference(key: ExpandedHeightPreferenceKey.self, value: proxy.size.height)
                            }
                        }
                    }
                )
                .modifier(BouncyHeightModifier(
                    height: isExpanded ? (fixedExpandedHeight ?? expandedHeight) : 0,
                    alignment: expandUpwards ? .bottom : .top
                ))
                .animation(isExpanded ? (enableBouncyExpansion ? .spring(response: 0.4, dampingFraction: 0.6) : .easeInOut(duration: 0.25)) : .easeOut(duration: 0.2), value: isExpanded)
                .animation(enableBouncyExpansion ? .spring(response: 0.4, dampingFraction: 0.6) : .easeInOut(duration: 0.25), value: expandedHeight)
                .allowsHitTesting(isExpanded)
                .onPreferenceChange(ExpandedHeightPreferenceKey.self) { height in
                    guard isExpanded else { return }
                    DispatchQueue.main.async {
                        if fixedExpandedHeight == nil && height > 0 && abs(height - expandedHeight) > 2.0 {
                            if isExpanded && expandedHeight > 0 {
                                let anim: Animation = enableBouncyExpansion ? .spring(response: 0.4, dampingFraction: 0.6) : .easeInOut(duration: 0.25)
                                withAnimation(anim) {
                                    expandedHeight = height
                                }
                            } else {
                                expandedHeight = height
                            }
                            if isExpanded && !isPreview, let id = keepAliveId {
                                let totalPillHeight = effectiveBaseHeight + height
                                VisorProWindowManager.shared.setOverlayExpandedHeight(overlayId: id, pillHeight: totalPillHeight)
                            }
                        }
                    }
                }
        }
        .frame(width: width, alignment: isPreview ? .center : (expandUpwards ? .bottom : .top))
        .background(
            ZStack {
                // MARK: Inner Glow Layer (Anchored to bottom track)
                if showProgressBar && shouldShowGlow {
                    TaperedBottomCapsuleTrack(inset: 0.0, strokeWidth: 3.5, cornerRadius: radius)
                        .fill(effectiveBarColor)
                        .opacity(customGlowOpacity ?? ((colorScheme == .dark ? 0.12 : 0.25) * mediaKeyManager.glowIntensity))
                        .mask(
                            Group {
                                if isTimeoutMode {
                                    HStack(spacing: 0) {
                                        TimeoutProgressBar(
                                            trackWidth: width,
                                            isHovering: isGloballyHovered || isExpanded,
                                            initialDuration: timeoutDuration,
                                            hoverOutDuration: timeoutDuration,
                                            isPreview: isPreview,
                                            hasGlow: true
                                        )
                                        Spacer(minLength: 0)
                                    }
                                    .id(timeoutEventId)
                                } else {
                                    ZStack(alignment: .leading) {
                                        Color.clear
                                        HStack(spacing: 0) {
                                            Rectangle()
                                                .frame(width: width)
                                            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                                                .frame(width: 24)
                                        }
                                        .offset(x: -((width + 24) * (1.0 - prog)))
                                    }
                                }
                            }
                        )
                        .allowsHitTesting(false)
                }
                
                // MARK: Bottom Progress Track & Active Line
                if showProgressBar {
                    // Background Track (recessed groove undertone + clear translucent track)
                    TaperedBottomCapsuleTrack(inset: 0.0, strokeWidth: 3.5, cornerRadius: radius)
                        .fill(Color.black.opacity(colorScheme == .dark ? 0.40 : 0.15))
                        .allowsHitTesting(false)
                    
                    TaperedBottomCapsuleTrack(inset: 0.0, strokeWidth: 3.5, cornerRadius: radius)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.24) : Color.black.opacity(0.20))
                        .allowsHitTesting(false)
                    
                    // Active Progress Line / Timeout Countdown Frame
                    TaperedBottomCapsuleTrack(inset: 0.0, strokeWidth: 3.5, cornerRadius: radius)
                        .fill(effectiveBarColor)
                        .shadow(color: effectiveBarColor.opacity(0.85), radius: 4, y: 1)
                        .mask(
                            Group {
                                if isTimeoutMode {
                                    HStack(spacing: 0) {
                                        TimeoutProgressBar(
                                            trackWidth: width,
                                            isHovering: isGloballyHovered || isExpanded,
                                            initialDuration: timeoutDuration,
                                            hoverOutDuration: timeoutDuration,
                                            isPreview: isPreview
                                        )
                                        Spacer(minLength: 0)
                                    }
                                    .id(timeoutEventId)
                                } else {
                                    ZStack(alignment: .leading) {
                                        Color.clear
                                        Rectangle()
                                            .frame(width: width)
                                            .offset(x: -(width * (1.0 - prog)))
                                    }
                                }
                            }
                        )
                        .allowsHitTesting(false)
                }
            }
        )
        .contentShape(bendedShape)
        .modifier(LiquidGlassBackgroundModifier(shape: bendedShape, isPreview: isPreview, isDark: effectiveIsDark))
        .overlay(
            LiquidGlassRimOverlay(shape: bendedShape, bendProgress: bendProgress, buttonCenter: buttonCenter, cutoutSize: cutoutSize, isAround: false)
        )
        .overlay(alignment: .topLeading) {
            if enableCloseButton && allowCloseButton {
                Image(systemName: "xmark")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(effectiveIsDark ? Color.white.opacity(0.85) : Color.black.opacity(0.70))
                    .frame(width: 20, height: 20)
                    .modifier(LiquidGlassCircleModifier(isPreview: isPreview, isDark: effectiveIsDark))
                    .contentShape(Circle())
                    .scaleEffect(isCloseButtonHovered ? 1.08 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isCloseButtonHovered)
                    .onHover { hovering in
                        isCloseButtonHovered = hovering
                    }
                    .onTapGesture {
                        if isPreview {
                            NotificationCenter.default.post(name: NSNotification.Name("PreviewDismissTriggered"), object: nil)
                        } else if let id = keepAliveId {
                            mediaKeyManager.forceHide(overlayId: id)
                        }
                    }
                    .conditionalPointingHandCursor(isEnabled: !isPreview)
                    .offset(x: buttonCenter.x - 10, y: dynamicOffset)
                    .opacity(shouldShowCloseButton ? 1 : 0)
                    .animation(shouldShowCloseButton ? .spring(response: 0.3, dampingFraction: 0.7) : .easeOut(duration: 0.2), value: shouldShowCloseButton)
            }
        }
        .onHoverExact { hovering in
            let anim: Animation = enableBouncyExpansion ? .spring(response: 0.38, dampingFraction: 0.65) : .easeInOut(duration: 0.22)
            withAnimation(anim) {
                isHovering = hovering
            }
            triggerKeepAlive(hoveringOverride: hovering)
            if allowCloseButton {
                updateBendProgress()
            }
        }
        .onChange(of: isGloballyHovered) { _, _ in
            updateBendProgress()
        }
        .onChange(of: keepCloseButtonWhenExpanded) { _, _ in
            updateBendProgress()
        }
        .onChange(of: isExpandable) { _, newValue in
            if !newValue && isExpanded {
                withAnimation(.easeOut(duration: 0.2)) {
                    isExpanded = false
                }
            }
        }
        .onChange(of: hasLanded) { _, _ in
            updateBendProgress()
        }
        .onChange(of: enableCloseButton) { _, _ in
            updateBendProgress()
        }
        .onChange(of: isExpanded) { _, expanded in
            updateBendProgress()
            let baseH = effectiveBaseHeight
            let expandedH = expanded ? (fixedExpandedHeight ?? expandedHeight) : 0
            let totalPillHeight = baseH + expandedH
            if !isPreview, let id = keepAliveId {
                VisorProWindowManager.shared.setOverlayExpandedHeight(overlayId: id, pillHeight: totalPillHeight)
            }
            if expanded {
                expandedKeepAliveTimer?.invalidate()
                expandedKeepAliveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    DispatchQueue.main.async {
                        triggerKeepAlive(expandedOverride: true)
                    }
                }
                DispatchQueue.main.async {
                    triggerKeepAlive(expandedOverride: true)
                }
            } else {
                let anim: Animation = enableBouncyExpansion ? .spring(response: 0.38, dampingFraction: 0.65) : .easeInOut(duration: 0.22)
                withAnimation(anim) {
                    isMinimalExpandedByClick = false
                }
                expandedKeepAliveTimer?.invalidate()
                expandedKeepAliveTimer = nil
                DispatchQueue.main.async {
                    triggerKeepAlive(expandedOverride: false)
                }
            }
        }
        .onChange(of: fixedExpandedHeight) { _, newH in
            if isExpanded, let newH = newH, !isPreview, let id = keepAliveId {
                let total = effectiveBaseHeight + newH
                VisorProWindowManager.shared.setOverlayExpandedHeight(overlayId: id, pillHeight: total)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PreviewWillExit"))) { _ in
            if isPreview {
                hasLanded = false
                bendProgress = 0.0
                isMinimalExpandedByClick = false
                if isExpanded {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isExpanded = false
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PreviewDidEnter"))) { _ in
            if isPreview {
                hasLanded = true
                updateBendProgress()
            }
        }
        .onChange(of: OverlayStateRelay.shared.closingPanels.contains(keepAliveId ?? "")) { _, isClosing in
            if isClosing {
                hasLanded = false
                bendProgress = 0.0
                isMinimalExpandedByClick = false
                if isExpanded {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isExpanded = false
                    }
                }
            }
        }
        .onAppear {
            if isPreview {
                hasLanded = true
                updateBendProgress()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    hasLanded = true
                    updateBendProgress()
                }
            }
        }
        .onDisappear {
            hasLanded = false
            bendProgress = 0.0
            expandedKeepAliveTimer?.invalidate()
            expandedKeepAliveTimer = nil
            isMinimalExpandedByClick = false
            if !isPreview, let id = keepAliveId {
                VisorProWindowManager.shared.setOverlayExpandedHeight(overlayId: id, pillHeight: effectiveBaseHeight, animated: false)
            }
        }
        .activeMaterialAppearanceIfAvailable()
        .environment(\.controlActiveState, .key)
    }
    
    private func updateBendProgress() {
        guard allowCloseButton else {
            if bendProgress != 0 {
                bendProgress = 0
            }
            return
        }
        let target: CGFloat = shouldShowCloseButton ? 1.0 : 0.0
        if bendProgress != target {
            if target == 0.0 {
                withAnimation(.easeOut(duration: 0.2)) {
                    bendProgress = 0.0
                }
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    bendProgress = 1.0
                }
            }
        }
    }
}
