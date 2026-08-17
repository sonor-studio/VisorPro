import SwiftUI

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
    
    var listHeight: CGFloat = 0
    var customWidth: CGFloat = 260
    var customHeight: CGFloat = 56
    
    var supportDragGesture: Bool = false
    var onDrag: ((CGFloat) -> Void)? = nil
    var onLeftTap: (() -> Void)? = nil
    var onRightTap: (() -> Void)? = nil
    var onSimpleTap: (() -> Void)? = nil
    
    var isExpandable: Bool = true
    var expandUpwards: Bool = false
    var keepAliveId: String? = nil
    var disableTimeoutMode: Bool = false
    
    @ViewBuilder var baseContent: () -> BaseContent
    @ViewBuilder var expandedContent: () -> ExpandedContent
    
    @State private var isDragging: Bool = false
    @State private var holdTimer: Timer? = nil
    @State private var isHovering: Bool = false
    @State private var expandedKeepAliveTimer: Timer? = nil
    @State private var timeoutProgress: CGFloat = 1.0
    
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
        let baseHeight: CGFloat = customHeight
        let outerRadius: CGFloat = baseHeight / 2
        let trackPadding: CGFloat = 4
        let innerPadding: CGFloat = 3
        let innerRadius: CGFloat = outerRadius - trackPadding
        let trackWidth: CGFloat = width - (trackPadding * 2)
        
        let currentHeight = isExpanded && isExpandable ? baseHeight + listHeight : baseHeight
        
        ZStack(alignment: .top) {
            ZStack(alignment: .leading) {
                // WARSTWA 0.5: Cień wewnętrznego kafelka (pada na zewnętrzne szkło, ale nie na pasek postępu)
                ZStack {
                    RoundedRectangle(cornerRadius: max(0, innerRadius - 0.75), style: .continuous)
                        .fill(Color.black)
                        .padding(0.75)
                        .shadow(color: Color.black.opacity(0.45), radius: 1.8, x: 0, y: 0)
                    RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                        .fill(Color.black)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
                .padding(trackPadding)
                .frame(width: width, height: currentHeight)

                // WARSTWA 1: Baza
                Group {
                    RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.3), lineWidth: innerPadding)
                        .padding(trackPadding)
                }
                .frame(width: width, height: currentHeight)
                
                // WARSTWA 2: Pasek postępu
                if showProgressBar {
                    ZStack {
                        if fillCenter {
                            RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                                .fill(isMuted ? Color.secondary.opacity(0.85) : barColor.opacity(0.95))
                                .padding(trackPadding)
                        } else {
                            RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                                .strokeBorder(isMuted ? Color.secondary.opacity(0.85) : barColor.opacity(0.95), lineWidth: innerPadding)
                                .padding(trackPadding)
                        }
                    }
                    .frame(width: width, height: currentHeight)
                    .mask(
                        Group {
                            if isTimeoutMode {
                                HStack(spacing: 0) {
                                    Spacer().frame(width: trackPadding)
                                    Rectangle()
                                        .modifier(TimeoutProgressBarModifier(progress: timeoutProgress, trackWidth: trackWidth))
                                    Spacer(minLength: 0)
                                }
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
                
                // WARSTWA 3: Szkło wewnątrz paska
                ZStack {
                    Color.clear.background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: innerRadius - innerPadding, style: .continuous))
                    
                    if colorScheme == .dark {
                        RoundedRectangle(cornerRadius: innerRadius - innerPadding, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    } else {
                        RoundedRectangle(cornerRadius: innerRadius - innerPadding, style: .continuous)
                            .fill(Color.white.opacity(0.25))
                    }
                    
                    RoundedRectangle(cornerRadius: innerRadius - innerPadding, style: .continuous)
                        .strokeBorder(Color.glassBorder, lineWidth: 1)
                }
                .padding(trackPadding + innerPadding)
                .frame(width: width, height: currentHeight)
            }
            .frame(width: width, height: currentHeight)
            .contentShape(RoundedRectangle(cornerRadius: innerRadius + trackPadding, style: .continuous))
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
                                    let timer = Timer(timeInterval: 0.2, repeats: false) { _ in
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
                                if supportDragGesture {
                                    if value.startLocation.x <= 50 && onLeftTap != nil {
                                        onLeftTap?()
                                    } else {
                                        onRightTap?()
                                        if isExpandable {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                                isExpanded.toggle()
                                            }
                                        }
                                    }
                                } else {
                                    onSimpleTap?()
                                    if isExpandable {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                            isExpanded.toggle()
                                        }
                                    }
                                }
                            }
                        }
                        isDragging = false
                    }
            )
            
            // Górna warstwa tekst/ikony
            baseContent()
                .frame(width: width, height: baseHeight)
                .allowsHitTesting(false)
            
            // Szuflada z zawartością - zawsze rozwija się w dół pod nagłówkiem
            expandedContent()
                .frame(width: width, height: isExpanded ? listHeight : 0, alignment: .top)
                .padding(.top, baseHeight)
                .clipped()
                .opacity(isExpanded ? 1 : 0)
        }
        .frame(width: width, height: isExpanded && isExpandable ? baseHeight + listHeight : baseHeight, alignment: .top)
        .background(
            (colorScheme == .dark ? Color.black.opacity(0.25) : Color.white.opacity(0.55))
                .background(.thickMaterial)
                .clipShape(RoundedRectangle(cornerRadius: outerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                        .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.9), lineWidth: colorScheme == .dark ? 1 : 1.5)
                )
        )
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: max(0, outerRadius - 1), style: .continuous)
                    .fill(Color.black)
                    .padding(1)
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                    .fill(Color.black)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
        )
        .onAppear {
            if isTimeoutMode {
                timeoutProgress = 1.0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    if !(isGloballyHovered || isExpanded) {
                        let duration = max(0.1, timeoutDuration - 0.2)
                        withAnimation(.linear(duration: duration)) {
                            timeoutProgress = 0.0
                        }
                    }
                }
            }
        }
        .onHoverExact { hovering in
            isHovering = hovering
            triggerKeepAlive(hoveringOverride: hovering)
            updateTimeoutAnimation(renew: hovering)
        }
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                expandedKeepAliveTimer?.invalidate()
                expandedKeepAliveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    DispatchQueue.main.async {
                        triggerKeepAlive(expandedOverride: true)
                    }
                }
                triggerKeepAlive(expandedOverride: true)
                updateTimeoutAnimation(renew: true)
            } else {
                expandedKeepAliveTimer?.invalidate()
                expandedKeepAliveTimer = nil
                if !isPreview, let keepAliveId = keepAliveId {
                    mediaKeyManager.keepAlive(for: keepAliveId, isHovering: isHovering)
                }
                updateTimeoutAnimation(renew: isHovering)
            }
        }
        .onChange(of: timeoutEventId) { _, _ in
            if isTimeoutMode {
                timeoutProgress = 1.0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    if !(isGloballyHovered || isExpanded) {
                        let duration = max(0.1, timeoutDuration - 0.2)
                        withAnimation(.linear(duration: duration)) {
                            timeoutProgress = 0.0
                        }
                    }
                }
            }
        }
        .onChange(of: mediaKeyManager.globalHoveredTypes) { _, _ in
            updateTimeoutAnimation(renew: false)
        }
    }
    
    private func updateTimeoutAnimation(renew: Bool) {
        guard isTimeoutMode else { return }
        if renew || isGloballyHovered || isExpanded {
            withAnimation(.easeOut(duration: 0.2)) {
                timeoutProgress = 1.0
            }
        } else {
            let duration = max(0.1, timeoutDuration - 0.2)
            withAnimation(.linear(duration: duration)) {
                timeoutProgress = 0.0
            }
        }
    }
    
    private func triggerKeepAlive(hoveringOverride: Bool? = nil, expandedOverride: Bool? = nil) {
        if !isPreview, let keepAliveId = keepAliveId {
            let currentHover = hoveringOverride ?? isHovering
            let currentExpanded = expandedOverride ?? isExpanded
            mediaKeyManager.keepAlive(for: keepAliveId, isHovering: currentHover || currentExpanded)
        }
    }
}
