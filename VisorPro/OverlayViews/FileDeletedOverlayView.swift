import SwiftUI

struct FileDeletedOverlayView: View {
    @State private var isExpanded: Bool = false
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @EnvironmentObject var overlayState: OverlayStateRelay
    var isPreview: Bool = false
    


    private func getFileIconInfo(fileName: String) -> String {
        let ext = fileName.split(separator: ".").last?.lowercased() ?? ""
        switch ext {
        case "pdf": return "doc.text.fill"
        case "png", "jpg", "jpeg", "gif", "svg", "webp": return "photo.fill"
        case "mp4", "mov", "avi", "mkv": return "play.rectangle.fill"
        case "mp3", "wav", "aac": return "waveform.circle.fill"
        case "zip", "rar", "7z", "tar", "gz": return "doc.zipper"
        case "txt", "md", "csv": return "doc.plaintext.fill"
        case "doc", "docx", "pages": return "doc.text.fill"
        case "xls", "xlsx", "numbers": return "chart.bar.doc.fill"
        case "key", "ppt", "pptx": return "chart.pie.fill"
        case "swift", "py", "js", "html", "css", "json", "xml", "cpp", "c", "h": return "curlybraces.square.fill"
        case "dmg", "pkg", "app": return "app.fill"
        default: return "doc.fill"
        }
    }

    var body: some View {
        let overlayPosition = MediaKeyManager.shared.getOverlayPosition(for: "fileDeletedOverlayPosition")
        let themeColor = OverlayColorManager.shared.getOverlayColor(for: "colorOnFileDeleted", defaultColor: .orange)
        let trackWidth: CGFloat = 260 - 6
        
        let fileName = isPreview ? "Presentation.key" : overlayState.lastDeletedFileName
        let fileSizeMB = isPreview ? 24.5 : overlayState.lastDeletedFileSizeMB
        let fileIcon = isPreview ? NSWorkspace.shared.icon(forFile: "/System/Applications/TextEdit.app") : overlayState.lastDeletedFileIcon
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            progress: 1.0,
            customProgressMask: AnyView(
                TimeoutProgressBar(trackWidth: trackWidth, isHovering: isExpanded || overlayState.globalHoveredTypes.contains("fileDeleted"), initialDuration: MediaKeyManager.notificationDuration, hoverOutDuration: MediaKeyManager.notificationDuration, isPreview: isPreview)
                    .id(overlayState.trashEventId)
            ),
            barColor: themeColor,
            fillCenter: false,
            isMuted: false,
            supportDragGesture: false,
            onRightTap: {
                if !isPreview {
                    restoreFile()
                    mediaKeyManager.forceHide(overlayId: "fileDeleted")
                }
            },
            onSimpleTap: {
                if !isPreview {
                    mediaKeyManager.keepAlive(for: "fileDeleted", isHovering: true)
                }
            },
            isExpandable: true,
            expandUpwards: overlayPosition.hasPrefix("bottom"),
            keepAliveId: "fileDeleted",
            baseContent: {
                HStack(alignment: .center, spacing: 12) {
                    if fileSizeMB < 0, let icon = fileIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                    } else {
                        let iconName = getFileIconInfo(fileName: fileName)
                        Image(systemName: iconName)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 28, height: 28)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Moved to Trash")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Text(fileName)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Spacer(minLength: 0)
                    
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.1))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
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
                            Text("Size")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Text(fileSizeMB < 0 ? "--" : (fileSizeMB >= 1000 ? String(format: "%.2f GB", fileSizeMB / 1000.0) : String(format: "%.2f MB", fileSizeMB)))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        Divider()
                            .frame(height: 24)
                        
                        VStack(alignment: .center, spacing: 4) {
                            Text("Type")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Text(fileSizeMB < 0 ? "FOLDER" : (fileName.contains(".") ? String(fileName.split(separator: ".").last!).uppercased() : "FILE"))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 16)
                    
                    HStack(spacing: 12) {
                        HStack {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Restore")
                        }
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.1))
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                        .onTapGesture {
                            if !isPreview {
                                restoreFile()
                                mediaKeyManager.forceHide(overlayId: "fileDeleted")
                            }
                        }
                        .pointingHandCursor()
                        
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete")
                        }
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.15))
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                        .onTapGesture {
                            if !isPreview {
                                deletePermanently()
                                mediaKeyManager.forceHide(overlayId: "fileDeleted")
                            }
                        }
                        .pointingHandCursor()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
            }
        )
    }
    
    private func restoreFile() {
        guard let url = overlayState.lastDeletedFileURL else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let scriptSource = """
            tell application "Finder"
                activate
                reveal (POSIX file "\(url.path)")
            end tell
            delay 0.1
            tell application "System Events"
                key code 51 using command down
            end tell
            """
            if let script = NSAppleScript(source: scriptSource) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
                if let err = error {
                }
            }
        }
    }
    
    private func deletePermanently() {
        guard let url = overlayState.lastDeletedFileURL else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
            }
        }
    }
}
