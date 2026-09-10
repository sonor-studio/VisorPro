import SwiftUI

struct LanguageOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @EnvironmentObject var overlayState: OverlayStateRelay
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
        
        let displayLanguage = isPreview ? (previewLanguage ?? "English (US)") : overlayState.currentKeyboardLanguage
        let langPos = MediaKeyManager.shared.getOverlayPosition(for: "languageOverlayPosition")
        let actionColor = OverlayColorManager.shared.getOverlayColor(for: "colorOnLanguageChange", defaultColor: .blue)
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            hasTimeoutProgress: true,
            timeoutEventId: overlayState.languageEventId,
            barColor: actionColor,
            fillCenter: false,
            customWidth: 260,
            customHeight: 56,
            supportDragGesture: false,
            onSimpleTap: {
                // Languages are now pre-loaded to prevent animation stutter.
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
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(availableLanguages, id: \.id) { layout in
                        LanguageRowView(
                            layout: layout,
                            isPreview: isPreview,
                            tintColor: actionColor,
                            onSelect: {
                                if !isPreview {
                                    overlayState.currentKeyboardLanguage = layout.name
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
                .padding(.horizontal, 4 + 3 + 4)
            }
        )
        .id(overlayState.languageEventId)
        .onAppear {
            if isPreview {
                availableLanguages = [
                    KeyboardLayout(id: "1", name: "English (US)", isSelected: true),
                    KeyboardLayout(id: "2", name: "Spanish", isSelected: false),
                    KeyboardLayout(id: "3", name: "Emoji", isSelected: false)
                ]
            } else {
                availableLanguages = mediaKeyManager.getAvailableLanguages()
            }
        }
        .onChange(of: overlayState.currentKeyboardLanguage) { _, _ in
            if !isPreview {
                availableLanguages = mediaKeyManager.getAvailableLanguages()
            }
        }
    }
}

struct LanguageRowView: View {
    let layout: KeyboardLayout
    let isPreview: Bool
    var tintColor: Color = .blue
    let onSelect: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(layout.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
                if layout.isSelected || (isPreview && layout.name == "English (US)") {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(tintColor)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovering ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .pointingHandCursor()
        .onHoverExact { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

#Preview {
    LanguageOverlayView(isPreview: true, previewLanguage: "English (US)")
        .environmentObject(MediaKeyManager())
        .environmentObject(OverlayStateRelay.shared)
}
