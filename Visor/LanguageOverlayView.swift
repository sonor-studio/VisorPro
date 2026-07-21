import SwiftUI
import Carbon

struct LanguageOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @State private var isHovering: Bool = false
    var isPreview: Bool = false
    var previewLanguage: String? = nil
    
    private var languageName: String {
        previewLanguage ?? mediaKeyManager.currentKeyboardLanguage
    }
    
    var body: some View {
        let width: CGFloat = 260
        let height: CGFloat = 56
        let trackPadding: CGFloat = 4
        let innerPadding: CGFloat = 3
        
        let trackWidth = width - (trackPadding * 2)
        let trackHeight = height - (trackPadding * 2)
        let innerWidth = trackWidth - (innerPadding * 2)
        let innerHeight = trackHeight - (innerPadding * 2)
        
        ZStack(alignment: .leading) {
            // WARSTWA 1: Baza (Szkło + grubsza szara ramka)
            ZStack {
                ActiveVisualEffectView()
                    .clipShape(Capsule())
                
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: innerPadding)
                    .frame(width: trackWidth, height: trackHeight)
            }
            .frame(width: width, height: height)
            
            // WARSTWA 2: Kolorowa ramka (Fioletowa/Pomarańczowa)
            Capsule()
                .strokeBorder(Color.orange.opacity(0.85), lineWidth: innerPadding)
                .frame(width: trackWidth, height: trackHeight)
                .mask(
                    HStack(spacing: 0) {
                        TimeoutProgressBar(trackWidth: trackWidth, isHovering: isHovering, initialDuration: MediaKeyManager.notificationDuration, hoverOutDuration: MediaKeyManager.notificationDuration)
                            .id(mediaKeyManager.languageEventId)
                        Spacer(minLength: 0)
                    }
                )
                .padding(.leading, trackPadding)
            
            // WARSTWA 3: Górna warstwa (Glass Blur z informacjami)
            HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Keyboard Layout")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        MarqueeText(text: languageName.isEmpty ? "Unknown" : languageName, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                    }
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16)
                .frame(width: innerWidth, height: innerHeight)
                .glassEffect(.thinMaterial, in: Capsule())
            .padding(.leading, trackPadding + innerPadding)
        }
        .frame(width: width, height: height)
        .contentShape(Capsule())
        .onHover { hovering in
            if !isPreview {
                isHovering = hovering
                mediaKeyManager.keepAlive(for: "language", isHovering: hovering)
            }
        }
        
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(20)
        .applyTheme(mediaKeyManager.overlayTheme)
        .onChange(of: isHovering) { hovering in
            if !isPreview {
                if hovering {
                } else {
                }
            }
        }
    }
}

#Preview {
    LanguageOverlayView(isPreview: true, previewLanguage: "Polski")
        .environmentObject(MediaKeyManager())
}
