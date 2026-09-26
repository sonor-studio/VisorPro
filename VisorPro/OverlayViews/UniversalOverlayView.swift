import SwiftUI

struct BendedCornerShape: InsettableShape, Sendable {
    typealias InsetShape = BendedCornerShape

    var radius: CGFloat
    var bendAmount: CGFloat
    var absoluteCutoutCenter: CGPoint
    var cutoutRadius: CGFloat
    var frameOffset: CGPoint
    var isRightSide: Bool = false
    
    var insetAmount: CGFloat = 0
    
    nonisolated var animatableData: CGFloat {
        get { bendAmount }
        set { bendAmount = newValue }
    }
    
    nonisolated func inset(by amount: CGFloat) -> BendedCornerShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
    
    nonisolated func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = max(0, radius - insetAmount)
        let w = rect.width
        let h = rect.height
        
        p.move(to: CGPoint(x: w - r - insetAmount, y: insetAmount))
        p.addArc(center: CGPoint(x: w - r - insetAmount, y: insetAmount + r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        
        p.addLine(to: CGPoint(x: w - insetAmount, y: h - r - insetAmount))
        p.addArc(center: CGPoint(x: w - r - insetAmount, y: h - r - insetAmount), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        
        p.addLine(to: CGPoint(x: insetAmount + r, y: h - insetAmount))
        p.addArc(center: CGPoint(x: insetAmount + r, y: h - r - insetAmount), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        
        let cx = absoluteCutoutCenter.x - frameOffset.x
        let cy = absoluteCutoutCenter.y - frameOffset.y
        
        let C2_x = insetAmount + r
        let C2_y = insetAmount + r
        let R2 = r
        
        let dx = C2_x - cx
        let dy = C2_y - cy
        let d = max(sqrt(dx*dx + dy*dy), 0.001) // Prevent division by zero
        
        let targetR1 = cutoutRadius + insetAmount
        let gap = d - R2
        let effectiveBend = max(0, min(1, bendAmount))
        let R1 = gap + (targetR1 - gap) * effectiveBend
        
        let a = (R1*R1 - R2*R2 + d*d) / (2 * d)
        let hSquared = R1*R1 - a*a
        let h_val = sqrt(max(0, hSquared))
        
        let P2_x = cx + a * dx / d
        let P2_y = cy + a * dy / d
        
        let i1_x = P2_x + h_val * dy / d
        let i1_y = P2_y - h_val * dx / d
        
        let i2_x = P2_x - h_val * dy / d
        let i2_y = P2_y + h_val * dx / d
        
        let intA = i1_y > i2_y ? CGPoint(x: i1_x, y: i1_y) : CGPoint(x: i2_x, y: i2_y)
        let intB = i1_y > i2_y ? CGPoint(x: i2_x, y: i2_y) : CGPoint(x: i1_x, y: i1_y)
        
        let cornerCenterY = insetAmount + r
        let cornerCenterX = insetAmount + r
        
        let leftLineEndY = (bendAmount > 0.0001 && intA.y > cornerCenterY) ? intA.y : cornerCenterY
        p.addLine(to: CGPoint(x: insetAmount, y: leftLineEndY))
        
        // Top left corner (the bended one)
        if bendAmount > 0.0001 {
            func norm(_ a: CGFloat) -> CGFloat { return a < 0 ? a + 2 * .pi : a }
            
            if intA.y <= cornerCenterY {
                let angleStart1 = norm(atan2(0, -r))
                let angleEnd1 = norm(atan2(intA.y - C2_y, intA.x - C2_x))
                p.addArc(center: CGPoint(x: C2_x, y: C2_y), radius: R2, startAngle: Angle(radians: Double(angleStart1)), endAngle: Angle(radians: Double(angleEnd1)), clockwise: false)
            }
            
            let angleStart2 = atan2(intA.y - cy, intA.x - cx)
            let angleEnd2 = atan2(intB.y - cy, intB.x - cx)
            
            var sA = angleStart2
            let eA = angleEnd2
            if sA < eA { sA += 2 * .pi } // Force DECREASING direction
            
            let steps = 24
            for i in 1...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let currentAngle = sA + (eA - sA) * t
                p.addLine(to: CGPoint(x: cx + R1 * cos(currentAngle), y: cy + R1 * sin(currentAngle)))
            }
            
            if intB.x <= cornerCenterX {
                let angleStart3 = norm(atan2(intB.y - C2_y, intB.x - C2_x))
                let angleEnd3 = norm(atan2(-r, 0))
                p.addArc(center: CGPoint(x: C2_x, y: C2_y), radius: R2, startAngle: Angle(radians: Double(angleStart3)), endAngle: Angle(radians: Double(angleEnd3)), clockwise: false)
            }
        } else {
            p.addArc(center: CGPoint(x: cornerCenterX, y: cornerCenterY), radius: r, startAngle: .degrees(180), endAngle: .degrees(-90), clockwise: false)
        }
        
        p.closeSubpath()
        
        if isRightSide {
            let transform = CGAffineTransform(translationX: rect.width, y: 0)
                .scaledBy(x: -1, y: 1)
            return p.applying(transform)
        }
        
        return p
    }
}



struct ExpandedHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct BouncyHeightModifier: AnimatableModifier {
    var height: CGFloat
    
    var animatableData: CGFloat {
        get { height }
        set { height = newValue }
    }
    
    func body(content: Content) -> some View {
        content.frame(height: round(max(0, height)), alignment: .top)
    }
}

struct UniversalOverlayView<BaseContent: View, ExpandedContent: View>: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @Environment(\.colorScheme) var colorScheme
    
    var isPreview: Bool = false
    @Binding var isExpanded: Bool    


    var showProgressBar: Bool = false
    var progress: CGFloat = 0
    var customProgressMask: AnyView? = nil
    var hasTimeoutProgress: Bool = false
    var timeoutDuration: Double = MediaKeyManager.notificationDuration
    var timeoutEventId: AnyHashable? = nil
    var barColor: Color = .blue
    var fillCenter: Bool = true
    var isMuted: Bool = false
    
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
    var disableTimeoutMode: Bool = false
    var fixedExpandedHeight: CGFloat? = nil
    
    @ViewBuilder var baseContent: () -> BaseContent
    @ViewBuilder var expandedContent: () -> ExpandedContent
    
    @State private var isDragging: Bool = false
    @State private var holdTimer: Timer? = nil
    @State private var isHovering: Bool = false
    @State private var expandedKeepAliveTimer: Timer? = nil
    @State private var isAnimating: Bool = false
    @State private var expandedHeight: CGFloat = 0
    @State private var bendProgress: CGFloat = 0
    @AppStorage("enableCloseButton") private var enableCloseButton = false
    @AppStorage("keepCloseButtonWhenExpanded") private var keepCloseButtonWhenExpanded = true
    @AppStorage("closeButtonOnRight") private var closeButtonOnRight = false
    
    private var isGloballyHovered: Bool {
        guard let keepAliveId = keepAliveId else { return isHovering }
        return isHovering || mediaKeyManager.globalHoveredTypes.contains(keepAliveId)
    }
    
    private var isTimeoutMode: Bool {
        if disableTimeoutMode { return false }
        return hasTimeoutProgress || (showProgressBar && !fillCenter && customProgressMask == nil && progress >= 1.0)
    }
    
    var body: some View {
        let width: CGFloat = customWidth
        let dynamicOffset: CGFloat = -2
        let buttonCenter = CGPoint(x: closeButtonOnRight ? width - (dynamicOffset + 10) : dynamicOffset + 10, y: dynamicOffset + 10)
        let cutoutCenterForShape = CGPoint(x: closeButtonOnRight ? width - buttonCenter.x : buttonCenter.x, y: buttonCenter.y)
        let baseHeight: CGFloat = customHeight
        let outerRadius: CGFloat = customCornerRadius ?? (baseHeight / 2)
        let trackPadding: CGFloat = 3
        let innerRadius: CGFloat = max(0, outerRadius - trackPadding)
        let innerPadding: CGFloat = 3
        let cutoutSize: CGFloat = 12
        let trackWidth: CGFloat = width - (trackPadding * 2)
        let effectiveBarColor: Color = isMuted ? Color.offStateGray.opacity(0.95) : barColor.opacity(0.95)
        
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                                ZStack(alignment: .leading) {
                    baseContent()
                        .frame(width: width, height: baseHeight)
                        .allowsHitTesting(false)
                        .animation(nil, value: isExpanded)
        
                        
                    HStack(spacing: 0) {
                        if onLeftTap != nil {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: 60)
                                .contentShape(Rectangle())
                                .pointingHandCursor()
                        }
                        if (!isExpandable && onSimpleTap != nil) || isExpandable {
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .pointingHandCursor()
                        } else {
                            Spacer()
                        }
                        if onRightTap != nil && !supportDragGesture {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: 50)
                                .contentShape(Rectangle())
                                .pointingHandCursor()
                        }
                    }
                    .frame(width: width, height: baseHeight)
                }
                
                expandedContent()
                    .padding(.bottom, 16)
                    .frame(width: width)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(
                        Group {
                            if fixedExpandedHeight == nil {
                                GeometryReader { proxy in
                                    Color.clear.preference(key: ExpandedHeightPreferenceKey.self, value: proxy.size.height)
                                }
                            }
                        }
                    )
                    .modifier(BouncyHeightModifier(height: isExpanded ? (fixedExpandedHeight ?? expandedHeight) : 0))
                    .opacity(isExpanded ? 1 : 0)
                    .allowsHitTesting(isExpanded)
                    .onPreferenceChange(ExpandedHeightPreferenceKey.self) { height in
                        if fixedExpandedHeight == nil && height > 0 && abs(height - expandedHeight) > 2.0 {
                            if isExpanded {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedHeight = height
                                }
                            } else {
                                expandedHeight = height
                            }
                        }
                    }
            }
            .frame(width: width, alignment: expandUpwards ? .bottom : .top)

        .background(
            ZStack(alignment: .leading) {
                // WARSTWA 1: Baza
                Group {
                    BendedCornerShape(radius: innerRadius, bendAmount: bendProgress, absoluteCutoutCenter: cutoutCenterForShape, cutoutRadius: cutoutSize + trackPadding, frameOffset: CGPoint(x: trackPadding, y: trackPadding), isRightSide: closeButtonOnRight)
                        .strokeBorder(Color.primary.opacity(0.3), style: StrokeStyle(lineWidth: innerPadding, lineCap: .round, lineJoin: .round))
                        .padding(trackPadding)
                }
                
                ZStack {
                    (colorScheme == .dark ? Color(white: 0.20, opacity: 0.98) : Color(white: 0.96, opacity: 0.98))
                        .clipShape(BendedCornerShape(radius: innerRadius - innerPadding, bendAmount: bendProgress, absoluteCutoutCenter: cutoutCenterForShape, cutoutRadius: cutoutSize + trackPadding + innerPadding, frameOffset: CGPoint(x: trackPadding + innerPadding, y: trackPadding + innerPadding), isRightSide: closeButtonOnRight))
                    
                    if colorScheme == .dark {
                        BendedCornerShape(radius: innerRadius - innerPadding, bendAmount: bendProgress, absoluteCutoutCenter: cutoutCenterForShape, cutoutRadius: cutoutSize + trackPadding + innerPadding, frameOffset: CGPoint(x: trackPadding + innerPadding, y: trackPadding + innerPadding), isRightSide: closeButtonOnRight)
                            .fill(Color.white.opacity(0.08))
                    } else {
                        BendedCornerShape(radius: innerRadius - innerPadding, bendAmount: bendProgress, absoluteCutoutCenter: cutoutCenterForShape, cutoutRadius: cutoutSize + trackPadding + innerPadding, frameOffset: CGPoint(x: trackPadding + innerPadding, y: trackPadding + innerPadding), isRightSide: closeButtonOnRight)
                            .fill(Color.white.opacity(0.25))
                    }
                    
                    BendedCornerShape(radius: innerRadius - innerPadding, bendAmount: bendProgress, absoluteCutoutCenter: cutoutCenterForShape, cutoutRadius: cutoutSize + trackPadding + innerPadding, frameOffset: CGPoint(x: trackPadding + innerPadding, y: trackPadding + innerPadding), isRightSide: closeButtonOnRight)
                        .strokeBorder(Color.glassBorder, style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                }
                .padding(trackPadding + innerPadding)

                if showProgressBar {
                    ZStack {
                        if fillCenter {
                            BendedCornerShape(radius: innerRadius, bendAmount: bendProgress, absoluteCutoutCenter: cutoutCenterForShape, cutoutRadius: cutoutSize + trackPadding, frameOffset: CGPoint(x: trackPadding, y: trackPadding), isRightSide: closeButtonOnRight)
                                .fill(effectiveBarColor)
                                .padding(trackPadding)
                        } else {
                            BendedCornerShape(radius: innerRadius, bendAmount: bendProgress, absoluteCutoutCenter: cutoutCenterForShape, cutoutRadius: cutoutSize + trackPadding, frameOffset: CGPoint(x: trackPadding, y: trackPadding), isRightSide: closeButtonOnRight)
                                .strokeBorder(effectiveBarColor, style: StrokeStyle(lineWidth: innerPadding, lineCap: .round, lineJoin: .round))
                                .padding(trackPadding)
                        }
                    }
                    .mask(
                        Group {
                            if isTimeoutMode {
                                HStack(spacing: 0) {
                                    Spacer().frame(width: trackPadding)
                                    TimeoutProgressBar(
                                        trackWidth: trackWidth,
                                        isHovering: isGloballyHovered || isExpanded,
                                        initialDuration: timeoutDuration,
                                        hoverOutDuration: timeoutDuration,
                                        isPreview: isPreview
                                    )
                                    Spacer(minLength: 0)
                                }
                                .id(timeoutEventId)
                            } else if let customMask = customProgressMask {
                                HStack(spacing: 0) {
                                    Spacer().frame(width: trackPadding)
                                    customMask
                                    Spacer(minLength: 0)
                                }
                            } else {
                                HStack(spacing: 0) {
                                    Spacer().frame(width: trackPadding)
                                    Rectangle()
                                        .frame(width: max(0, trackWidth * progress))
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                    )
                }
                
            }
        )
        .contentShape(RoundedRectangle(cornerRadius: outerRadius))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if isPreview { return }
                    if supportDragGesture {
                        if isDragging {
                            let v = max(0, min(1, value.location.x / width))
                            onDrag?(v)
                        } else {
                            let moved = abs(value.translation.width) >= 8 || abs(value.translation.height) >= 8
                            if moved {
                                holdTimer?.invalidate()
                                holdTimer = nil
                                isDragging = true
                                let v = max(0, min(1, value.location.x / width))
                                onDrag?(v)
                            } else if holdTimer == nil {
                                let timer = Timer(timeInterval: 0.5, repeats: false) { _ in
                                    DispatchQueue.main.async {
                                        isDragging = true
                                        let v = max(0, min(1, value.location.x / width))
                                        onDrag?(v)
                                    }
                                }
                                RunLoop.main.add(timer, forMode: .common)
                                holdTimer = timer
                            }
                        }
                    }
                }
                .onEnded { value in
                    holdTimer?.invalidate()
                    holdTimer = nil
                    
                    if !isDragging {
                        let moved = abs(value.translation.width) >= 8 || abs(value.translation.height) >= 8
                        if !moved {
                            let locX = value.startLocation.x
                            if onLeftTap != nil && locX <= 60 {
                                onLeftTap?()
                            } else if onRightTap != nil && !supportDragGesture && locX >= width - 50 {
                                onRightTap?()
                            } else {
                                if isExpandable {
                                    if !isAnimating {
                                        isAnimating = true
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isExpanded.toggle()
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            isAnimating = false
                                        }
                                    }
                                } else {
                                    onSimpleTap?()
                                }
                            }
                        }
                    }
                    isDragging = false
                }
        )

        .background(
            (colorScheme == .dark ? Color(white: 0.12, opacity: 0.98) : Color(white: 0.90, opacity: 0.98))
                .clipShape(BendedCornerShape(radius: outerRadius, bendAmount: bendProgress, absoluteCutoutCenter: cutoutCenterForShape, cutoutRadius: cutoutSize, frameOffset: .zero, isRightSide: closeButtonOnRight))
                .overlay(
                    BendedCornerShape(radius: outerRadius, bendAmount: bendProgress, absoluteCutoutCenter: cutoutCenterForShape, cutoutRadius: cutoutSize, frameOffset: .zero, isRightSide: closeButtonOnRight)
                        .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.9), style: StrokeStyle(lineWidth: colorScheme == .dark ? 1 : 1.5, lineCap: .round, lineJoin: .round))
                )

        )
        .background(
            ZStack {
                BendedCornerShape(radius: max(0, outerRadius - 1), bendAmount: bendProgress, absoluteCutoutCenter: cutoutCenterForShape, cutoutRadius: cutoutSize + 1, frameOffset: CGPoint(x: 1, y: 1), isRightSide: closeButtonOnRight)
                    .fill(Color.black)
                    .padding(1)
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                
                BendedCornerShape(radius: outerRadius, bendAmount: bendProgress, absoluteCutoutCenter: cutoutCenterForShape, cutoutRadius: cutoutSize, frameOffset: .zero, isRightSide: closeButtonOnRight)
                    .fill(Color.black)
                    .blendMode(.destinationOut)
                
                if bendProgress > 0 {
                    Circle()
                        .fill(Color.black)
                        .frame(width: (cutoutSize + 1) * 2, height: (cutoutSize + 1) * 2)
                        .position(x: buttonCenter.x, y: buttonCenter.y)
                        .blendMode(.destinationOut)
                        .opacity(bendProgress)
                }
            }
            .compositingGroup()
        )
        .onHoverExact { hovering in
            isHovering = hovering
            triggerKeepAlive(hoveringOverride: hovering)
            updateBendProgress()
        }
        .onChange(of: isGloballyHovered) { _, _ in
            updateBendProgress()
        }
        .onChange(of: keepCloseButtonWhenExpanded) { _, _ in
            updateBendProgress()
        }
        .onChange(of: isExpandable) { _, newValue in
            if !newValue && isExpanded {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded = false
                }
            }
        }
        .onDisappear {
            expandedKeepAliveTimer?.invalidate()
            expandedKeepAliveTimer = nil
            holdTimer?.invalidate()
            holdTimer = nil
        }
        .onChange(of: isExpanded) { _, expanded in
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
                expandedKeepAliveTimer?.invalidate()
                expandedKeepAliveTimer = nil
                DispatchQueue.main.async {
                    triggerKeepAlive(expandedOverride: false)
                }
            }
        }
            if enableCloseButton && !isPreview {
                
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(colorScheme == .dark ? Color(white: 0.3) : Color(white: 0.96))
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                    .contentShape(Circle())
                    .onTapGesture {
                        if let id = keepAliveId {
                            mediaKeyManager.forceHide(overlayId: id)
                        }
                    }
                    .pointingHandCursor()
                .offset(x: buttonCenter.x - 10, y: dynamicOffset)
                .opacity(shouldShowCloseButton ? 1 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: shouldShowCloseButton)
            }
        }
    }
    
    private var shouldShowCloseButton: Bool {
        guard enableCloseButton && !isPreview else { return false }
        if keepCloseButtonWhenExpanded {
            return isGloballyHovered
        } else {
            return isHovering
        }
    }
    
    private func updateBendProgress() {
        let target: CGFloat = shouldShowCloseButton ? 1.0 : 0.0
        if bendProgress != target {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                bendProgress = target
            }
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
}
