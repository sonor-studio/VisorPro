import SwiftUI

struct UniversalOverlayView<BaseContent: View, ExpandedContent: View>: View {
    @AppStorage("overlayExpansionStyle") private var overlayExpansionStyle: String = "drawer"
    
    var isPreview: Bool = false
    @Binding var isExpanded: Bool
    
    var showProgressBar: Bool = false
    var progress: CGFloat = 0
    var customProgressMask: AnyView? = nil
    var barColor: Color = .blue
    var fillCenter: Bool = true
    var isMuted: Bool = false
    
    var listHeight: CGFloat = 0
    var customWidth: CGFloat = 260
    
    var supportDragGesture: Bool = false
    var onDrag: ((CGFloat) -> Void)? = nil
    var onLeftTap: (() -> Void)? = nil
    var onRightTap: (() -> Void)? = nil
    var onSimpleTap: (() -> Void)? = nil
    
    var isExpandable: Bool = true
    var expandUpwards: Bool = false
    
    @ViewBuilder var baseContent: () -> BaseContent
    @ViewBuilder var expandedContent: () -> ExpandedContent
    
    @State private var isDragging: Bool = false
    @State private var holdTimer: Timer? = nil
    
    var body: some View {
        let width: CGFloat = customWidth
        let baseHeight: CGFloat = 56
        let outerRadius: CGFloat = 28
        let trackPadding: CGFloat = 4
        let innerPadding: CGFloat = 3
        let innerRadius: CGFloat = outerRadius - trackPadding
        
        let trackWidth = width - (trackPadding * 2)
        
        let isStretch = overlayExpansionStyle == "stretch"
        let currentHeight = isStretch && isExpanded ? baseHeight + listHeight : baseHeight
        
        ZStack(alignment: expandUpwards ? .bottom : .top) {
            ZStack(alignment: .leading) {
                // WARSTWA 1: Baza
                Group {
                    RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.15), lineWidth: innerPadding)
                        .padding(trackPadding)
                }
                .frame(width: width, height: currentHeight)
                
                // WARSTWA 2: Pasek postępu
                if showProgressBar {
                    Group {
                        if fillCenter {
                            RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                                .fill(isMuted ? Color.secondary.opacity(0.7) : barColor.opacity(0.85))
                                .padding(trackPadding)
                        } else {
                            RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                                .strokeBorder(isMuted ? Color.secondary.opacity(0.7) : barColor.opacity(0.85), lineWidth: innerPadding)
                                .padding(trackPadding)
                        }
                    }
                    .frame(width: width, height: currentHeight)
                    .mask(
                        Group {
                            if let customMask = customProgressMask {
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
                    Color.clear.background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: innerRadius - innerPadding, style: .continuous))
                    
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
                                    if value.startLocation.x <= 50 {
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
            
            // Szuflada z zawartością
            expandedContent()
                .frame(width: width, height: isExpanded ? listHeight : 0, alignment: expandUpwards ? .bottom : .top)
                .padding(expandUpwards ? .bottom : .top, isExpanded ? baseHeight : baseHeight)
                .clipped()
                .opacity(isExpanded ? 1 : 0)
        }
        .background(
            Color.clear.background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: outerRadius, style: .continuous))
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}
