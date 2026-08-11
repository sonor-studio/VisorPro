import SwiftUI

struct LanguageOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @State private var isHovering = false
    @State private var isExpanded = false
    @State private var expandedKeepAliveTimer: Timer?
    @State private var availableLanguages: [KeyboardLayout] = []
    
    let isPreview: Bool
    let previewLanguage: String?
    
    init(isPreview: Bool = false, previewLanguage: String? = nil) {
        self.isPreview = isPreview
        self.previewLanguage = previewLanguage
    }
    
    var body: some View {
        let width: CGFloat = 260
        let baseHeight: CGFloat = 56
        let trackPadding: CGFloat = 4
        let trackWidth = width - (trackPadding * 2)
        
        let outerRadius: CGFloat = 28
        let innerPadding: CGFloat = 3
        let innerRadius = outerRadius - trackPadding
        
        let displayLanguage = isPreview ? (previewLanguage ?? "Polski") : mediaKeyManager.currentKeyboardLanguage
        
        let maxListHeight: CGFloat = 160
        let calculatedListHeight = CGFloat(availableLanguages.count) * 36 + 10
        let listHeight = min(maxListHeight, calculatedListHeight)
        let currentHeight = isExpanded ? baseHeight + listHeight : baseHeight
        
        ZStack(alignment: .top) {
            ZStack(alignment: .leading) {
                // WARSTWA 1: Baza
                Group {
                    RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.15), lineWidth: innerPadding)
                        .padding(trackPadding)
                }
                .frame(width: width, height: currentHeight)
                
                // WARSTWA 2: Kolorowa ramka
                Group {
                    RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                        .strokeBorder(Color.orange.opacity(0.85), lineWidth: innerPadding)
                        .padding(trackPadding)
                }
                .frame(width: width, height: currentHeight)
                .mask(
                    HStack(spacing: 0) {
                        Spacer().frame(width: trackPadding)
                        TimeoutProgressBar(trackWidth: trackWidth, isHovering: isHovering || isExpanded, initialDuration: MediaKeyManager.notificationDuration, hoverOutDuration: MediaKeyManager.notificationDuration)
                            .id(mediaKeyManager.languageEventId)
                        Spacer(minLength: 0)
                    }
                )
                
                // WARSTWA 3: Wewnętrzne szkło
                ZStack {
                    Color.clear.background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: innerRadius - innerPadding, style: .continuous))
                    
                    RoundedRectangle(cornerRadius: innerRadius - innerPadding, style: .continuous)
                        .strokeBorder(Color.glassBorder, lineWidth: 1)
                }
                .padding(trackPadding + innerPadding)
                .frame(width: width, height: currentHeight)
            }
            .frame(width: width, height: currentHeight)
            
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
            .padding(.horizontal, 16 + trackPadding + innerPadding)
            .frame(width: width, height: baseHeight)
            .allowsHitTesting(false)
            
            // Rozwijana lista
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
                .padding(.horizontal, trackPadding + innerPadding + 4)
            }
            .frame(width: width, height: isExpanded ? listHeight : 0, alignment: .top)
            .padding(.top, baseHeight)
            .clipped()
            .opacity(isExpanded ? 1 : 0)
        }
        .background(
            Color.clear.background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: outerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                        .strokeBorder(Color.glassBorder, lineWidth: 1)
                        .opacity(isExpanded ? 1 : 0)
                )
        )
        .frame(width: width, height: isExpanded ? baseHeight + listHeight : baseHeight, alignment: .top)
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(20)
        .onTapGesture {
            if !isExpanded && !isPreview {
                availableLanguages = mediaKeyManager.getAvailableLanguages()
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        }
        .onHover { hovering in
            isHovering = hovering
            if !isPreview {
                mediaKeyManager.keepAlive(for: "language", isHovering: hovering || isExpanded)
            }
        }
        .onChange(of: isExpanded) { expanded in
            if expanded {
                expandedKeepAliveTimer?.invalidate()
                expandedKeepAliveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    DispatchQueue.main.async {
                        if !isPreview { mediaKeyManager.keepAlive(for: "language", isHovering: true) }
                    }
                }
            } else {
                expandedKeepAliveTimer?.invalidate()
                expandedKeepAliveTimer = nil
                if !isPreview {
                    mediaKeyManager.keepAlive(for: "language", isHovering: isHovering)
                }
            }
        }
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
        .onHover { hovering in
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
