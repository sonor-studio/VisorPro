import SwiftUI


struct InlineControlView<Control: View>: View {
    let icon: String
    let title: String
    let control: Control
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .fixedSize(horizontal: true, vertical: false)
                .lineLimit(1)
            control
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .nativeGlassBackground()
    }
}

struct ModulePopover: Identifiable {
    var id: String { title }
    let icon: String
    let title: String
    let content: AnyView
    var show: Bool = true
    init(icon: String, title: String, content: AnyView) {
        self.icon = icon
        self.title = title
        self.content = content
        self.show = true
    }
    
    init(icon: String, title: String, show: Bool, content: AnyView) {
        self.icon = icon
        self.title = title
        self.show = show
        self.content = content
    }
    
    init(icon: String, title: String, content: AnyView, show: Bool) {
        self.icon = icon
        self.title = title
        self.content = content
        self.show = show
    }
}

private struct PopoverContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 {
            value = max(value, next)
        }
    }
}

struct AdaptivePopoverContent: View {
    let content: AnyView
    let maxHeight: CGFloat = 520
    @State private var naturalHeight: CGFloat = 0
    
    var body: some View {
        Group {
            if naturalHeight > maxHeight {
                ScrollView(.vertical, showsIndicators: true) {
                    measuredContent
                }
                .frame(height: maxHeight)
            } else {
                measuredContent
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private var measuredContent: some View {
        content
            .toggleStyle(.switch)
            .padding(14)
            .frame(minWidth: 380, maxWidth: 550)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: PopoverContentHeightKey.self, value: proxy.size.height)
                }
            )
            .onPreferenceChange(PopoverContentHeightKey.self) { measured in
                if measured > 0 && abs(measured - naturalHeight) > 1 {
                    naturalHeight = measured
                }
            }
    }
}

struct ModuleSettingsLayout<Preview: View>: View {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("PremiumLicenseKey") private var savedLicenseKey = ""
    let title: String
    @Binding var isEnabled: Bool
    var isPremium: Bool = false
    
    @ViewBuilder let preview: () -> Preview
    let popovers: [ModulePopover]
    var inlineControls: [AnyView] = []
    var headerTrailingControls: AnyView? = nil
    var previewTopOffset: CGFloat? = nil
    
    // State to track which popover is presented
    @State private var activePopoverId: String? = nil
    
    private var isLockedByPremium: Bool {
        isPremium && savedLicenseKey.isEmpty
    }
    
    var body: some View {
        ZStack {
            // Full-bleed preview background
            PreviewBackgroundView(minHeight: 620, fullBleed: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            
            // Dim scrim for readability
            Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05)
            
            // Tap-catcher behind all content to dismiss popovers
            if activePopoverId != nil {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        activePopoverId = nil
                    }
            }
            
            // Bottom controls dock (pinned to bottom, zIndex: 1)
            VStack(spacing: 0) {
                Spacer()
                
                if isLockedByPremium {
                    FloatingActionButton(
                        icon: "lock.fill",
                        label: "Premium Required",
                        isActive: activePopoverId == "premium_required"
                    ) {
                        if activePopoverId == "premium_required" {
                            activePopoverId = nil
                        } else {
                            activePopoverId = "premium_required"
                        }
                    }
                    .popover(isPresented: Binding(
                        get: { activePopoverId == "premium_required" },
                        set: { if !$0 { activePopoverId = nil } }
                    ), attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                        AdaptivePopoverContent(content: AnyView(PremiumLockedView()))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                } else if isEnabled && (!popovers.isEmpty || !inlineControls.isEmpty) {
                    FlowLayout(spacing: 12, rowSpacing: 12) {
                        ForEach(popovers.filter { $0.show }) { popover in
                            FloatingActionButton(
                                icon: popover.icon,
                                label: popover.title,
                                isActive: activePopoverId == popover.id
                            ) {
                                if activePopoverId == popover.id {
                                    activePopoverId = nil
                                } else {
                                    activePopoverId = popover.id
                                }
                            }
                            .popover(isPresented: Binding(
                                get: { activePopoverId == popover.id },
                                set: { if !$0 { activePopoverId = nil } }
                            ), attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                                AdaptivePopoverContent(content: popover.content)
                            }
                        }
                        ForEach(0..<inlineControls.count, id: \.self) { index in
                            inlineControls[index]
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .zIndex(1)
            
            // Header & live preview layer (zIndex: 10 so overlays expand freely over everything)
            VStack(spacing: 0) {
                // Top: Enable/Disable buttons
                if !isLockedByPremium {
                    ZStack {
                        HStack(spacing: 10) {
                            Button {
                                isEnabled = false
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("Disabled")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                            }
                            .buttonStyle(InteractiveGlassButtonStyle(isActive: !isEnabled))
                            
                            Button {
                                isEnabled = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("Enabled")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                            }
                            .buttonStyle(InteractiveGlassButtonStyle(isActive: isEnabled))
                        }
                        
                        if let headerTrailingControls {
                            HStack {
                                Spacer()
                                headerTrailingControls
                            }
                            .padding(.trailing, 24)
                        }
                    }
                    .padding(.top, 20)
                }
                
                // Center: Overlay preview dynamically centered based on available space
                ZStack(alignment: .center) {
                    if isLockedByPremium || isEnabled {
                        if let previewTopOffset {
                            VStack(spacing: 0) {
                                Color.clear.frame(height: previewTopOffset)
                                preview()
                                Spacer(minLength: 0)
                            }
                        } else {
                            preview()
                                .frame(height: 56, alignment: .center)
                        }
                    } else {
                        DisabledModuleView(
                            icon: "power",
                            title: "\(title) Module is Disabled",
                            description: "Turn on the module to configure its overlays."
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.bottom, 80)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .zIndex(10)
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 12
    var rowSpacing: CGFloat = 12
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for row in rows {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowHeight
        }
        height += CGFloat(max(0, rows.count - 1)) * rowSpacing
        return CGSize(width: proposal.width ?? 0, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            
            // Calculate row width to center it
            let rowWidth = row.reduce(0) { $0 + $1.sizeThatFits(.unspecified).width } + CGFloat(max(0, row.count - 1)) * spacing
            var x = bounds.minX + (bounds.width - rowWidth) / 2
            
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y + (rowHeight - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + rowSpacing
        }
    }
    
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = []
        var currentRow: [LayoutSubview] = []
        var currentWidth: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentRow.isEmpty {
                currentRow.append(subview)
                currentWidth = size.width
            } else if currentWidth + spacing + size.width <= maxWidth {
                currentRow.append(subview)
                currentWidth += spacing + size.width
            } else {
                rows.append(currentRow)
                currentRow = [subview]
                currentWidth = size.width
            }
        }
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        return rows
    }
}
