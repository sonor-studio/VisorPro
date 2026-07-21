import SwiftUI
import Combine

struct MediaOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    var isPreview: Bool = false
    var previewTitle: String = "Sample Media"
    var previewArtist: String = "YouTube / Safari"
    var previewProgress: Double = 0.4
    var previewIsPlaying: Bool = false
    
    private var actualTitle: String {
        let t = isPreview ? previewTitle : mediaKeyManager.mediaTitle
        return t.isEmpty ? "Unknown Media" : t
    }
    
    private var actualArtist: String {
        isPreview ? previewArtist : mediaKeyManager.mediaArtist
    }
    
    private var actualIsPlaying: Bool {
        isPreview ? previewIsPlaying : mediaKeyManager.mediaIsPlaying
    }
    
    @State private var localElapsed: Double = 0
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    private var actualAction: String {
        isPreview ? "start" : mediaKeyManager.mediaAction
    }
    
    private var playbackProgress: CGFloat {
        if isPreview { return CGFloat(previewProgress) }
        let duration = mediaKeyManager.mediaDuration
        if duration > 0 {
            return CGFloat(min(max(localElapsed / duration, 0), 1))
        }
        return 0.0
    }
    
    private var actionColor: Color {
        switch actualAction {
        case "start": return .blue
        case "resume": return .green
        case "pause": return .red
        case "end": return .secondary
        default: return .red
        }
    }
    
    private var actionTitle: String {
        switch actualAction {
        case "start": return "STARTED"
        case "resume": return "RESUMED"
        case "pause": return "PAUSED"
        case "end": return "STOPPED"
        default: return actualIsPlaying ? "RESUMED" : "PAUSED"
        }
    }
    
    private var actionIcon: String {
        switch actualAction {
        case "start": return "music.note"
        case "resume": return "play.fill"
        case "pause": return "pause.fill"
        case "end": return "stop.fill"
        default: return actualIsPlaying ? "play.fill" : "pause.fill"
        }
    }
    
    var body: some View {
        let width: CGFloat = 260
        let height: CGFloat = 72
        let trackPadding: CGFloat = 4
        let innerPadding: CGFloat = 3
        
        let trackWidth = width - (trackPadding * 2)
        let trackHeight = height - (trackPadding * 2)
        let innerWidth = trackWidth - (innerPadding * 2)
        let innerHeight = trackHeight - (trackPadding * 2)
        
        ZStack(alignment: .leading) {
            ZStack {
                ActiveVisualEffectView()
                    .clipShape(Capsule())
                
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: innerPadding)
                    .frame(width: trackWidth, height: trackHeight)
            }
            .frame(width: width, height: height)
            
            // Pasek postępu odtwarzania
            Capsule()
                .strokeBorder(actionColor.opacity(0.85), lineWidth: innerPadding)
                .frame(width: trackWidth, height: trackHeight)
                .mask(
                    HStack(spacing: 0) {
                        Rectangle()
                            .frame(width: trackWidth * playbackProgress)
                        Spacer(minLength: 0)
                    }
                )
                .padding(.leading, trackPadding)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: playbackProgress)
            
            HStack(alignment: .center, spacing: 14) {
                    Image(systemName: actionIcon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(actionTitle)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        MarqueeText(text: actualTitle, font: .system(size: 13, weight: .bold, design: .rounded), foregroundColor: .primary)
                            
                        if !actualArtist.isEmpty {
                            MarqueeText(text: actualArtist, font: .system(size: 11, weight: .medium, design: .rounded), foregroundColor: .secondary)
                        }
                    }
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 12)
                .frame(width: innerWidth, height: innerHeight)
                .glassEffect(.thinMaterial, in: Capsule())
            .padding(.leading, trackPadding + innerPadding)
        }
        .frame(width: width, height: height)
        .contentShape(Capsule())
        .onHover { isHovering in
            if !isPreview {
                mediaKeyManager.keepAlive(for: "media", isHovering: isHovering)
            }
        }
        
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(20)
        .applyTheme(mediaKeyManager.overlayTheme)
        .onAppear {
            localElapsed = mediaKeyManager.mediaElapsedTime
        }
        .onChange(of: mediaKeyManager.mediaElapsedTime) { oldValue, newValue in
            if actualAction != "start" && actualAction != "end" {
                localElapsed = newValue
            }
        }
        .onReceive(timer) { _ in
            if actualIsPlaying && actualAction != "start" && actualAction != "end" {
                localElapsed += 0.1
            }
        }
    }
}
