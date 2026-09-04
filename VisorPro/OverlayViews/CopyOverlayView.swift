import SwiftUI

struct CopyOverlayView: View {
    @State private var isExpanded: Bool = false
    @AppStorage("copyAllowExpansion") private var copyAllowExpansion: Bool = true
    
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    var isPreview: Bool = false
    var previewAction: String? = nil
    
    private var actualAction: String {
        previewAction ?? mediaKeyManager.clipboardAction
    }
    
    private var actionColor: Color {
        switch actualAction {
        case "copy": return Color(red: 0.25, green: 0.5, blue: 0.95)
        case "cut": return .red
        case "paste": return .green
        default: return Color(red: 0.25, green: 0.5, blue: 0.95)
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
            with: CGSize(width: 228, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(rect.height)
    }
    
    var body: some View {
        let displayedText = isPreview ? "1 cup all-purpose flour\n2 tablespoons sugar\n2 teaspoons baking powder\n1 cup milk\n1 egg" : (mediaKeyManager.copiedText.isEmpty ? actionFallbackText : mediaKeyManager.copiedText)
        let reqHeight = calculatedTextHeight(for: displayedText)
        let textNeedsExpansion = reqHeight > 22
        let canExpand = true
        let trackWidth: CGFloat = 260 - 8
        let copyPos = MediaKeyManager.shared.getOverlayPosition(for: "copyOverlayPosition")
        

        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            progress: 1.0,
            customProgressMask: AnyView(
                TimeoutProgressBar(trackWidth: trackWidth, isHovering: isExpanded || mediaKeyManager.globalHoveredTypes.contains("copy"), initialDuration: MediaKeyManager.notificationDuration, hoverOutDuration: MediaKeyManager.notificationDuration, isPreview: isPreview)
                    .id(mediaKeyManager.clipboardEventId)
            ),
            barColor: actionColor,
            fillCenter: false, // The original uses strokeBorder
            isMuted: false,
            supportDragGesture: false,
            onSimpleTap: {
                if canExpand {
                    // UniversalOverlayView will automatically toggle isExpanded
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded = false
                    }
                }
                if !isPreview {
                    mediaKeyManager.keepAlive(for: "copy", isHovering: true)
                }
            },
            isExpandable: canExpand && copyAllowExpansion,
            expandUpwards: copyPos.hasPrefix("bottom"),
            keepAliveId: "copy",
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
                        
                        if !(isExpanded && textNeedsExpansion) {
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
                    VStack(spacing: 12) {
                        if textNeedsExpansion {
                            ScrollView(showsIndicators: true) {
                                Text(displayedText)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 16) // Shifted to left edge, under the icon
                                    .padding(.trailing, 16)
                                    .padding(.top, 12)
                            }
                            
                            Divider()
                                .padding(.horizontal, 20)
                        }
                        
                        HStack(spacing: 8) {
                            if mediaKeyManager.clipboardSourceFolder == nil {
                                // Text Mode
                                VStack(alignment: .center, spacing: 4) {
                                    Text("App")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    Text(mediaKeyManager.clipboardSourceApp.isEmpty ? "Unknown" : mediaKeyManager.clipboardSourceApp)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                
                                Divider()
                                    .frame(height: 24)
                                
                                VStack(alignment: .center, spacing: 4) {
                                    Text("Characters")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    Text(mediaKeyManager.clipboardMetadataSize.isEmpty ? "Unknown" : mediaKeyManager.clipboardMetadataSize)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                // File Mode
                                VStack(alignment: .center, spacing: 4) {
                                    Text("Folder")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    Text(URL(fileURLWithPath: mediaKeyManager.clipboardSourceFolder!).lastPathComponent)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                
                                Divider()
                                    .frame(height: 24)
                                
                                VStack(alignment: .center, spacing: 4) {
                                    Text("Size")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    Text(mediaKeyManager.clipboardMetadataSize.isEmpty ? "Unknown" : mediaKeyManager.clipboardMetadataSize)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        .padding(.top, textNeedsExpansion ? 0 : 12)
                    }
                    .padding(.top, textNeedsExpansion ? -16 : 0)
                } else {
                    EmptyView()
                }
            }
        )
    }
}
