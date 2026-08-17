import SwiftUI

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
        let trackWidth: CGFloat = 260 - 8
        let copyPos = UserDefaults.standard.string(forKey: "copyOverlayPosition") ?? "bottom"
        

        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            progress: 1.0,
            customProgressMask: AnyView(
                TimeoutProgressBar(trackWidth: trackWidth, isHovering: isHovering || isExpanded || mediaKeyManager.globalHoveredTypes.contains("copy"), initialDuration: MediaKeyManager.notificationDuration, hoverOutDuration: MediaKeyManager.notificationDuration)
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

        .padding(20)
        .onHoverExact { hovering in
            isHovering = hovering
            if !isPreview {
                mediaKeyManager.keepAlive(for: "copy", isHovering: hovering || isExpanded)
            }
        }
        .onChange(of: isExpanded) { _, expanded in
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
        .onDisappear {
            expandedKeepAliveTimer?.invalidate()
            expandedKeepAliveTimer = nil
            if !isPreview {
                mediaKeyManager.keepAlive(for: "copy", isHovering: false)
            }
        }
        .applyTheme(mediaKeyManager.overlayTheme)
    }
}
