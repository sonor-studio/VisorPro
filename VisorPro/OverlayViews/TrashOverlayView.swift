import SwiftUI

struct TrashOverlayView: View {
    @State private var isExpanded: Bool = false
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @EnvironmentObject var overlayState: OverlayStateRelay
    var isPreview: Bool = false
    
    var body: some View {
        let trashOverlayPosition = MediaKeyManager.shared.getOverlayPosition(for: "trashOverlayPosition")
        let currentSize = (!isPreview && overlayState.trashAutoEmptied) ? 0.0 : (isPreview ? 12.5 : overlayState.trashSizeGB)
        let threshold = isPreview ? 10.0 : mediaKeyManager.trashSizeThresholdGB
        let percent = (!isPreview && overlayState.trashAutoEmptied) ? 0.0 : min(currentSize / max(threshold, 0.1), 1.0)
        
        let trackWidth: CGFloat = 260 - 6
        let themeColor = OverlayColorManager.shared.getOverlayColor(for: "colorOnTrashFull", defaultColor: .primary)
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            progress: percent,
            customProgressMask: AnyView(
                TimeoutProgressBar(trackWidth: trackWidth, isHovering: isExpanded || overlayState.globalHoveredTypes.contains("trash"), initialDuration: MediaKeyManager.notificationDuration, hoverOutDuration: MediaKeyManager.notificationDuration, isPreview: isPreview)
                    .id(overlayState.trashEventId)
            ),
            barColor: themeColor,
            fillCenter: false,
            isMuted: false,
            supportDragGesture: false,
            onRightTap: isPreview || !overlayState.trashAutoEmptied ? {
                if !isPreview {
                    TrashObserver.shared.emptyTrash(isAutoEmpty: true, freedSize: overlayState.trashSizeGB)
                }
                isExpanded = false
            } : nil,
            onSimpleTap: {
                if !isPreview {
                    mediaKeyManager.keepAlive(for: "trash", isHovering: true)
                }
            },
            isExpandable: !(!isPreview && overlayState.trashAutoEmptied),
            expandUpwards: trashOverlayPosition.hasPrefix("bottom"),
            keepAliveId: "trash",
            baseContent: {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: (!isPreview && overlayState.trashAutoEmptied) ? "trash" : "tray.full.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text((!isPreview && overlayState.trashAutoEmptied) ? "Trash Emptied" : "Trash is Full")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        HStack(alignment: .bottom, spacing: 4) {
                            if (!isPreview && overlayState.trashAutoEmptied) {
                                Text(String(format: "%.2f", overlayState.trashFreedSizeGB))
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                Text("GB Freed")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .padding(.bottom, 1)
                            } else {
                                Text("\(String(format: "%.2f", currentSize)) / \(String(format: "%.0f", threshold))")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                Text("GB")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .padding(.bottom, 1)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    
                    if !overlayState.trashAutoEmptied {
                        ZStack {
                            Circle()
                                .fill(Color.primary.opacity(0.1))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.leading, 23)
                .padding(.trailing, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            },
            expandedContent: {
                VStack(spacing: 12) {
                    Divider()
                        .padding(.horizontal, 16)
                        .opacity(0.5)
                    
                    HStack(spacing: 8) {
                        VStack(alignment: .center, spacing: 4) {
                            Text("Files")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Text(isPreview ? "42" : "\(overlayState.trashFileCount)")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        Divider()
                            .frame(height: 24)
                        
                        VStack(alignment: .center, spacing: 4) {
                            Text("Folders")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Text(isPreview ? "3" : "\(overlayState.trashFolderCount)")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        Divider()
                            .frame(height: 24)
                        
                        VStack(alignment: .center, spacing: 4) {
                            Text("Largest")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Text(isPreview ? "1.2 GB" : (overlayState.trashLargestItemMB >= 1000 ? String(format: "%.2f GB", overlayState.trashLargestItemMB / 1000.0) : String(format: "%.2f MB", overlayState.trashLargestItemMB)))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 16)
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Empty Trash")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(28 - 4 - 3)
                        .contentShape(RoundedRectangle(cornerRadius: 28 - 4 - 3))
                        .simultaneousGesture(TapGesture().onEnded {
                            if !isPreview {
                                TrashObserver.shared.emptyTrash(isAutoEmpty: true, freedSize: overlayState.trashSizeGB)
                                isExpanded = false
                            }
                        })
                        .pointingHandCursor()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
            }
        )
    }
}
