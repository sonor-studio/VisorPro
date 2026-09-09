import SwiftUI

struct CopyOverlayView: View {
    @State private var isExpanded: Bool = false
    @State private var previewItemId: UUID? = nil
    @State private var textNeedsExpansion: Bool = false
    @AppStorage("copyAllowExpansion") private var copyAllowExpansion: Bool = true
    @AppStorage("clipboardEnableHistory") var clipboardEnableHistory: Bool = true
    @AppStorage("clipboardEnablePreview") var clipboardEnablePreview: Bool = true
    @AppStorage("clipboardKeepExpandedOnPaste") var clipboardKeepExpandedOnPaste: Bool = false
    
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    var isPreview: Bool = false
    var previewAction: String? = nil
    
    private static let mockHistory: [ClipboardItem] = [
        ClipboardItem(id: UUID(), text: "1 cup all-purpose flour\n2 tablespoons sugar\n2 teaspoons baking powder\n1 cup milk\n1 egg", app: "Safari", folder: nil, size: "128 bytes", timestamp: Date()),
        ClipboardItem(id: UUID(), text: "https://example.com/recipe", app: "Google Chrome", folder: nil, size: "26 bytes", timestamp: Date().addingTimeInterval(-300)),
        ClipboardItem(id: UUID(), text: "Dinner at 8?", app: "Messages", folder: nil, size: "12 bytes", timestamp: Date().addingTimeInterval(-3600)),
        ClipboardItem(id: UUID(), text: "print('Hello World')", app: "Xcode", folder: nil, size: "20 bytes", timestamp: Date().addingTimeInterval(-7200))
    ]
    
    private var currentHistory: [ClipboardItem] {
        if isPreview {
            return CopyOverlayView.mockHistory
        }
        return mediaKeyManager.clipboardHistory
    }

    private var activePreviewId: UUID? {
        if let pid = previewItemId, currentHistory.contains(where: { $0.id == pid }) {
            return pid
        }
        return currentHistory.first?.id
    }
    
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
    
    private var displayedItemText: String {
        if let id = activePreviewId, let item = currentHistory.first(where: { $0.id == id }) {
            return item.text
        }
        return isPreview ? "1 cup all-purpose flour\n2 tablespoons sugar\n2 teaspoons baking powder\n1 cup milk\n1 egg" : (mediaKeyManager.copiedText.isEmpty ? actionFallbackText : mediaKeyManager.copiedText)
    }

    private var displayedApp: String {
        if let previewId = activePreviewId, let item = currentHistory.first(where: { $0.id == previewId }) {
            return item.app
        }
        return mediaKeyManager.clipboardSourceApp.isEmpty ? "Unknown" : mediaKeyManager.clipboardSourceApp
    }
    
    private var displayedFolder: String? {
        if let previewId = activePreviewId, let item = currentHistory.first(where: { $0.id == previewId }) {
            return item.folder
        }
        return mediaKeyManager.clipboardSourceFolder
    }

    private var displayedSize: String {
        if let previewId = activePreviewId, let item = currentHistory.first(where: { $0.id == previewId }) {
            return item.size
        }
        return mediaKeyManager.clipboardMetadataSize.isEmpty ? "Unknown" : mediaKeyManager.clipboardMetadataSize
    }
    

    var body: some View {
        let _ = print("CopyOverlayView: body evaluated (isPreview=\(isPreview))")
        let canExpand = (clipboardEnableHistory && !currentHistory.isEmpty) || (textNeedsExpansion && clipboardEnablePreview)
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
            barColor: OverlayColorManager.shared.getOverlayColor(for: actualAction == "copy" ? "colorOnCopy" : (actualAction == "cut" ? "colorOnCut" : "colorOnPaste"), defaultColor: actionColor),
            fillCenter: false, // The original uses strokeBorder
            isMuted: false,
            supportDragGesture: false,
            onSimpleTap: {
                handleSimpleTap(canExpand: canExpand)
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
                        
                        MarqueeText(text: displayedItemText, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                            .id(isExpanded)
                            .frame(height: 18)
                            .opacity((isExpanded && textNeedsExpansion && clipboardEnablePreview) ? 0 : 1)
                    }
                    .padding(.leading, 14)
                    .padding(.trailing, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 5)
            },
            expandedContent: {
                self.makeExpandedContent(canExpand: canExpand, textNeedsExpansion: textNeedsExpansion)
            }
        )
        .onAppear {
            updateTextExpansion()
        }
        .onChange(of: displayedItemText) { _, _ in
            updateTextExpansion()
        }
        .onChange(of: clipboardEnableHistory) { _, _ in
            // content shape may change, reset cached height so pre-measurement re-runs
        }
    }

    private func updateTextExpansion() {
        let font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        let rect = (displayedItemText as NSString).boundingRect(
            with: CGSize(width: 228, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        textNeedsExpansion = ceil(rect.height) > 22
    }

    private func handleSimpleTap(canExpand: Bool) {
        if !canExpand {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded = false
            }
        }
        if !isPreview {
            mediaKeyManager.keepAlive(for: "copy", isHovering: true)
        }
    }
    
    private func handleHistoryItemDelete(_ item: ClipboardItem) {
        if isPreview { return }
        withAnimation {
            mediaKeyManager.clipboardHistory.removeAll(where: { $0.id == item.id })
            if previewItemId == item.id {
                previewItemId = currentHistory.first?.id
            }
            if currentHistory.isEmpty {
                isExpanded = false
            }
        }
    }
    
    private func handleHistoryItemTap(_ item: ClipboardItem) {
        if !isPreview { mediaKeyManager.copyHistoryItemToPasteboard(item) }
        withAnimation {
            previewItemId = item.id
        }
        if !clipboardKeepExpandedOnPaste {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded = false
            }
        }
    }
    
    @ViewBuilder
    private func makeExpandedContent(canExpand: Bool, textNeedsExpansion: Bool) -> some View {

                if canExpand {
                    VStack(spacing: 4) {
                        if clipboardEnablePreview {
                            VStack(spacing: 12) {
                                if textNeedsExpansion {
                                    ScrollView(showsIndicators: true) {
                                        Text(displayedItemText)
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.leading, 16)
                                            .padding(.trailing, 8)
                                            .padding(.top, 12)
                                            .frame(width: 252, alignment: .leading)
                                    }
                                    .frame(maxHeight: 128)
                                    .padding(.trailing, 8)
                                    .onHover { hovering in
                                        DispatchQueue.main.async {
                                            if OverlayStateRelay.shared.isHoveringScrollView != hovering {
                                                OverlayStateRelay.shared.isHoveringScrollView = hovering
                                            }
                                        }
                                    }
                                    
                                    Divider()
                                        .padding(.horizontal, 20)
                                }
                                
                                HStack(spacing: 8) {
                                    if displayedFolder == nil {
                                        VStack(alignment: .center, spacing: 4) {
                                            Text("App")
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                            Text(displayedApp)
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        
                                        Divider().frame(height: 24)
                                        
                                        VStack(alignment: .center, spacing: 4) {
                                            Text("Characters")
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                            Text(displayedSize)
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .center)
                                    } else {
                                        VStack(alignment: .center, spacing: 4) {
                                            Text("Folder")
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                            Text(URL(fileURLWithPath: displayedFolder!).lastPathComponent)
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        
                                        Divider().frame(height: 24)
                                        
                                        VStack(alignment: .center, spacing: 4) {
                                            Text("Size")
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                            Text(displayedSize)
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .center)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                            }
                            .padding(.top, textNeedsExpansion ? -16 : 0)
                        } else {
                            EmptyView()
                        }
                        
                        if clipboardEnableHistory && !currentHistory.isEmpty {
                            if clipboardEnablePreview {
                                Divider()
                            }
                            
                            ScrollView {
                                
                                LazyVStack(spacing: 4) {
                                    ForEach(currentHistory) { item in
                                        ClipboardHistoryRowView(
                                            item: item,
                                            isActive: item.id == activePreviewId,
                                            showPreviewButton: clipboardEnablePreview,
                                            isPreview: isPreview,
                                            onPreview: {
                                                withAnimation {
                                                    previewItemId = item.id
                                                }
                                            },
                                            onDelete: {
                                                handleHistoryItemDelete(item)
                                            }
                                        )
                                        .onTapGesture {
                                            handleHistoryItemTap(item)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                                .frame(width: 252)
                            }
                            .frame(maxHeight: 128)
                            .padding(.trailing, 8)
                            .onHover { hovering in
                                DispatchQueue.main.async {
                                    if OverlayStateRelay.shared.isHoveringScrollView != hovering {
                                        OverlayStateRelay.shared.isHoveringScrollView = hovering
                                    }
                                }
                            }
                        }
                    }
                } else {
                    EmptyView()
                }
            
    }

}
struct ClipboardHistoryRowView: View {
    let item: ClipboardItem
    var isActive: Bool = false
    var showPreviewButton: Bool = true
    var isPreview: Bool = false
    var onPreview: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    @State private var isHovering = false
    @State private var isHoveringEye = false
    @State private var isHoveringTrash = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 10) {
            if showPreviewButton {
                Button(action: {
                    onPreview?()
                }) {
                    Image(systemName: "eye")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isActive ? .primary : (isHoveringEye ? .primary : .secondary))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { hovering in
                    isHoveringEye = hovering
                }
            }

            if let icon = getAppIcon(appName: item.app) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundColor(.secondary)
            }
            
            Text(item.text.replacingOccurrences(of: "\n", with: " "))
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer(minLength: 8)
            
            Text(timeAgo(from: item.timestamp))
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                
            Button(action: {
                onDelete?()
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isHoveringTrash ? .red : .secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hovering in
                isHoveringTrash = hovering
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isActive ? (colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1)) : (isHovering ? Color.secondary.opacity(0.1) : Color.clear))
        )
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    private static var iconCache: [String: NSImage] = [:]
    
    private func getAppIcon(appName: String) -> NSImage? {
        if appName.isEmpty || appName == "Unknown" { return nil }
        
        if let cached = Self.iconCache[appName] {
            return cached
        }
        
        let workspace = NSWorkspace.shared
        var foundIcon: NSImage? = nil
        
        if appName == "Xcode", let url = workspace.urlForApplication(withBundleIdentifier: "com.apple.dt.Xcode") {
            foundIcon = workspace.icon(forFile: url.path)
        } else if let path = workspace.urlForApplication(withBundleIdentifier: appName) {
            foundIcon = workspace.icon(forFile: path.path)
        } else {
            let pathInApplications = "/Applications/\(appName).app"
            if FileManager.default.fileExists(atPath: pathInApplications) {
                foundIcon = workspace.icon(forFile: pathInApplications)
            } else {
                let pathInSystemApplications = "/System/Applications/\(appName).app"
                if FileManager.default.fileExists(atPath: pathInSystemApplications) {
                    foundIcon = workspace.icon(forFile: pathInSystemApplications)
                }
            }
        }
        
        if let icon = foundIcon {
            Self.iconCache[appName] = icon
        }
        return foundIcon
    }
    
    private func timeAgo(from date: Date) -> String {
        if isPreview {
            if item.app == "Safari" { return "now" }
            if item.app == "Google Chrome" { return "5m" }
            if item.app == "Messages" { return "1h" }
            if item.app == "Xcode" { return "2h" }
            return "5m"
        }
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }
}
