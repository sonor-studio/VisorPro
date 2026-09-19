import SwiftUI

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

struct CopyOverlayView: View {
    @State private var isExpanded: Bool = false
    @State private var previewItemId: UUID? = nil
    @State private var scrollOffset: CGFloat = 0
    @State private var textNeedsExpansion: Bool = false
    @AppStorage("copyAllowExpansion") private var copyAllowExpansion: Bool = true
    @AppStorage("clipboardEnableHistory") var clipboardEnableHistory: Bool = true
    @AppStorage("clipboardEnablePreview") var clipboardEnablePreview: Bool = true
    @AppStorage("clipboardKeepExpandedOnPaste") var clipboardKeepExpandedOnPaste: Bool = false
    @AppStorage("clipboardShowPasswordToggle") private var clipboardShowPasswordToggle: Bool = true
    
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @EnvironmentObject var overlayState: OverlayStateRelay
    var isPreview: Bool = false
    var previewAction: String? = nil
    
    private func masked(_ text: String) -> String {
        guard clipboardShowPasswordToggle else { return text }
        let isCurrentlyMasked: Bool
        if let pid = activePreviewId, let item = currentHistory.first(where: { $0.id == pid }) {
            isCurrentlyMasked = item.isMasked ?? false
        } else {
            isCurrentlyMasked = false
        }
        guard isCurrentlyMasked else { return text }
        return "••••••••"
    }
    
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
        previewAction ?? overlayState.clipboardAction
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
        return isPreview ? "1 cup all-purpose flour\n2 tablespoons sugar\n2 teaspoons baking powder\n1 cup milk\n1 egg" : (overlayState.copiedText.isEmpty ? actionFallbackText : overlayState.copiedText)
    }

    private var displayedApp: String {
        if let previewId = activePreviewId, let item = currentHistory.first(where: { $0.id == previewId }) {
            return item.app
        }
        return overlayState.clipboardSourceApp.isEmpty ? "Unknown" : overlayState.clipboardSourceApp
    }
    
    private var displayedFolder: String? {
        if let previewId = activePreviewId, let item = currentHistory.first(where: { $0.id == previewId }) {
            return item.folder
        }
        return overlayState.clipboardSourceFolder
    }

    private var displayedSize: String {
        if let previewId = activePreviewId, let item = currentHistory.first(where: { $0.id == previewId }) {
            return item.size
        }
        return overlayState.clipboardMetadataSize.isEmpty ? "Unknown" : overlayState.clipboardMetadataSize
    }
    

    var body: some View {
        let canExpand = (clipboardEnableHistory && !currentHistory.isEmpty) || (textNeedsExpansion && clipboardEnablePreview)

        let copyPos = MediaKeyManager.shared.getOverlayPosition(for: "copyOverlayPosition")
        

        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            hasTimeoutProgress: true,
            timeoutEventId: overlayState.clipboardEventId,
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
                HStack(alignment: .center, spacing: 0) {
                    Image(systemName: actionIcon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 24)
                        .padding(.leading, 23)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(actionTitle)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        MarqueeText(text: masked(displayedItemText), font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                            .frame(height: 18)
                            .id("marquee-\(isExpanded)")
                            .opacity((isExpanded && textNeedsExpansion && clipboardEnablePreview) ? 0 : 1)
                    }
                    .padding(.leading, 12)
                    .padding(.trailing, 20)
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
        .onChange(of: masked(displayedItemText)) { _, _ in
            updateTextExpansion()
        }
        .onChange(of: clipboardEnableHistory) { _, _ in
            // content shape may change, reset cached height so pre-measurement re-runs
        }
    }

    private func updateTextExpansion() {
        let textToMeasure = masked(displayedItemText)
        let font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        let rect = (textToMeasure as NSString).boundingRect(
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
                                        Text(String(repeating: " ", count: 15) + masked(displayedItemText))
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 12)
                                            .padding(.top, 0)
                                            .padding(.bottom, 4)
                                            .background(
                                                GeometryReader { geo in
                                                    Color.clear.preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .named("scroll")).minY)
                                                }
                                            )
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    isExpanded = false
                                                }
                                            }
                                    }
                                    .coordinateSpace(name: "scroll")
                                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                                        scrollOffset = value
                                    }
                                    .mask(
                                        HStack(spacing: 0) {
                                            // LEWA STRONA (obszar ikony)
                                            VStack(spacing: 0) {
                                                Color.clear.frame(height: 14) // Kwadrat obcinający głębiej pod ikoną, zwiększający "margines zasłony"
                                                LinearGradient(gradient: Gradient(colors: [.clear, .black]), startPoint: .top, endPoint: .bottom)
                                                    .frame(height: 8) // Krótszy Fade pod kwadratem
                                                Color.black
                                            }
                                            .frame(width: 61)
                                            
                                            // ŚRODEK (dynamicznie obcinający tekst proporcjonalnie do ruchu scrolla)
                                            ZStack(alignment: .top) {
                                                // Maska obcinająca wyrównana do poziomu lewego cięcia ikony (docelowy stan po przesunięciu)
                                                VStack(spacing: 0) {
                                                    Color.clear.frame(height: 14)
                                                    LinearGradient(gradient: Gradient(colors: [.clear, .black]), startPoint: .top, endPoint: .bottom)
                                                        .frame(height: 8)
                                                    Color.black
                                                }
                                                
                                                // Maska górna w spoczynku (by nie obcinać pierwszej linii)
                                                // Zanika progresywnie, odsłaniając ucięcie, proporcjonalnie do offsetu przewijania (od 0 do -15 pikseli)
                                                VStack(spacing: 0) {
                                                    LinearGradient(gradient: Gradient(colors: [.clear, .black]), startPoint: .top, endPoint: .bottom)
                                                        .frame(height: 6)
                                                    Color.black
                                                }
                                                .opacity(max(0, min(1, 1.0 + (scrollOffset / 15.0))))
                                            }
                                            
                                            // PRAWY MARGINES OKNA (wyłącza z obcinania boczny pasek przewijania - scrollbar)
                                            VStack(spacing: 0) {
                                                LinearGradient(gradient: Gradient(colors: [.clear, .black]), startPoint: .top, endPoint: .bottom)
                                                    .frame(height: 6)
                                                Color.black
                                            }
                                            .frame(width: 20)
                                        }
                                    )
                                    .frame(maxHeight: 128)
                                    .offset(y: -28)
                                    .padding(.bottom, -28)
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
                                            isTextMasked: item.isMasked ?? false,
                                            showPasswordToggle: clipboardShowPasswordToggle,
                                            onPreview: {
                                                withAnimation {
                                                    previewItemId = item.id
                                                }
                                            },
                                            onDelete: {
                                                handleHistoryItemDelete(item)
                                            },
                                            onToggleMask: {
                                                if !isPreview {
                                                    withAnimation {
                                                        if let idx = mediaKeyManager.clipboardHistory.firstIndex(where: { $0.id == item.id }) {
                                                            var updatedItem = mediaKeyManager.clipboardHistory[idx]
                                                            updatedItem.isMasked = !(updatedItem.isMasked ?? false)
                                                            mediaKeyManager.clipboardHistory[idx] = updatedItem
                                                        }
                                                    }
                                                }
                                            }
                                        )
                                        .onTapGesture {
                                            handleHistoryItemTap(item)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.leading, 12)
                                .padding(.trailing, 4)
                            }
                            .frame(maxHeight: 128)
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
    var isTextMasked: Bool = false
    var showPasswordToggle: Bool = true
    var onPreview: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onToggleMask: (() -> Void)? = nil
    @State private var isHovering = false
    @State private var isHoveringEye = false
    @State private var isHoveringLock = false
    @State private var isHoveringTrash = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 6) {
            if showPreviewButton {
                Button(action: {
                    onPreview?()
                }) {
                    Image(systemName: "eye")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isActive ? .primary : (isHoveringEye ? .primary : .secondary))
                        .frame(width: 20, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { hovering in
                    isHoveringEye = hovering
                }
                .pointingHandCursor()
            }
            
            if showPasswordToggle {
                Button(action: {
                    onToggleMask?()
                }) {
                    Image(systemName: isTextMasked ? "lock.fill" : "lock.open.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isTextMasked ? .primary : (isHoveringLock ? .primary : .secondary))
                        .frame(width: 20, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { hovering in
                    isHoveringLock = hovering
                }
                .pointingHandCursor()
            }

            if let icon = getAppIcon(appName: item.app) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .frame(width: 14, height: 14)
                    .foregroundColor(.secondary)
            }
            
            Text((isTextMasked && showPasswordToggle) ? "••••••••" : item.text.replacingOccurrences(of: "\n", with: " "))
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, 2)
            
            Spacer(minLength: 0)
            
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
            .pointingHandCursor()
        }
        .padding(.vertical, 8)
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isActive ? (colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1)) : (isHovering ? Color.secondary.opacity(0.1) : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .pointingHandCursor()
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
        let timeDiff = Date().timeIntervalSince(date)
        let seconds = (timeDiff.isFinite && timeDiff >= Double(Int.min) && timeDiff <= Double(Int.max)) ? Int(timeDiff) : 0
        if seconds < 60 { return "now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }
}
