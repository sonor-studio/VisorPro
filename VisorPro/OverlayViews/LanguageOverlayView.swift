import SwiftUI

struct LanguageOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @State private var isExpanded = false
    @State private var availableLanguages: [KeyboardLayout] = []
    
    let isPreview: Bool
    let previewLanguage: String?
    
    init(isPreview: Bool = false, previewLanguage: String? = nil) {
        self.isPreview = isPreview
        self.previewLanguage = previewLanguage
    }
    
    var body: some View {
        
        let displayLanguage = isPreview ? (previewLanguage ?? "Polski") : mediaKeyManager.currentKeyboardLanguage
        
        let maxListHeight: CGFloat = 160
        let calculatedListHeight = CGFloat(availableLanguages.count) * 36 + 10
        let listHeight = min(maxListHeight, calculatedListHeight)
        let langPos = UserDefaults.standard.string(forKey: "languageOverlayPosition") ?? "bottom"
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            hasTimeoutProgress: true,
            timeoutEventId: mediaKeyManager.languageEventId,
            barColor: .orange,
            fillCenter: false,
            listHeight: listHeight,
            customWidth: 260,
            customHeight: 56,
            supportDragGesture: false,
            onSimpleTap: {
                if !isExpanded && !isPreview {
                    availableLanguages = mediaKeyManager.getAvailableLanguages()
                }
            },
            isExpandable: true,
            expandUpwards: langPos == "bottom",
            keepAliveId: "language",
            baseContent: {
                HStack(spacing: 16) {
                    Image(systemName: "globe")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 24, height: 24)
                    
                    Text(displayLanguage)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 16)
            },
            expandedContent: {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(availableLanguages, id: \.id) { layout in
                            LanguageRowView(
                                layout: layout,
                                isPreview: isPreview,
                                onSelect: {
                                    if !isPreview {
                                        mediaKeyManager.currentKeyboardLanguage = layout.name
                                        mediaKeyManager.selectLanguage(idToSelect: layout.id)
                                    }
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        isExpanded = false
                                    }
                                }
                            )
                        }
                    }
                    .padding(.top, 2)
                    .padding(.bottom, 8)
                    .padding(.horizontal, 8)
                }
            }
        )

                .applyTheme(mediaKeyManager.overlayTheme)
    }
}

struct LanguageRowView: View {
    let layout: KeyboardLayout
    let isPreview: Bool
    let onSelect: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(layout.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
                if layout.isSelected || (isPreview && layout.name == "Polski") {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(isHovering ? 0.05 : 0.001))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
        .onHoverExact { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

#Preview {
    LanguageOverlayView(isPreview: true, previewLanguage: "Polski")
        .environmentObject(MediaKeyManager())
}
