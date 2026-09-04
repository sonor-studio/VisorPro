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
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "globe")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Language")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            
                        MarqueeText(text: displayLanguage, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                    }
                    
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16 + 4 + 3)
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
                                    withAnimation(.easeInOut(duration: 0.2)) {
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
        .id(mediaKeyManager.languageEventId)
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
