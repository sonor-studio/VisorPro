import SwiftUI

struct LanguageOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("languageAllowExpansion") private var languageAllowExpansion: Bool = true
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
        let langPos = MediaKeyManager.shared.getOverlayPosition(for: "languageOverlayPosition")
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            hasTimeoutProgress: true,
            timeoutEventId: mediaKeyManager.languageEventId,
            barColor: .purple,
            fillCenter: false,
            customWidth: 260,
            customHeight: 56,
            supportDragGesture: false,
            onSimpleTap: {
                if !isExpanded && !isPreview {
                    availableLanguages = mediaKeyManager.getAvailableLanguages()
                }
            },
            isExpandable: languageAllowExpansion,
            expandUpwards: langPos.hasPrefix("bottom"),
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
                    
                    .padding(.horizontal, 8)
                }
            }
        )

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
                        .foregroundColor(.purple)
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
