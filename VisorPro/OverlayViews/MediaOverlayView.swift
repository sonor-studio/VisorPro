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
        let bundle = mediaKeyManager.mediaBundleId.lowercased()
        
        if bundle.contains("spotify") {
            return "headphones"
        } else if bundle.contains("music") {
            return "music.note"
        } else if bundle.contains("podcasts") {
            return "mic.fill"
        } else if bundle.contains("safari") {
            return "safari.fill"
        } else if bundle.contains("chrome") || bundle.contains("arc") || bundle.contains("edge") || bundle.contains("brave") {
            return "network"
        } else if bundle.contains("tv") {
            return "tv.fill"
        } else if mediaKeyManager.mediaDuration > 900.0 {
            return "earbuds"
        } else {
            return "music.note.list"
        }
    }
    
    @State private var isExpanded: Bool = false
    @State private var isDragging: Bool = false
    @State private var dragStartElapsed: Double = 0.0
    @State private var dragStartX: CGFloat = 0.0
    @State private var holdTimer: Timer? = nil
    
    private var isPodcastOrBrowser: Bool {
        if !mediaKeyManager.mediaAlbum.isEmpty {
            return false // Jeśli ma album, traktujemy to jako muzykę (prev/next track)
        }
        let bundleId = mediaKeyManager.mediaBundleId.lowercased()
        let browsers = ["safari", "chrome", "edge", "brave", "arc", "podcasts", "company.thebrowser"]
        return browsers.contains { bundleId.contains($0) }
    }

    var body: some View {
        let width: CGFloat = 260
        let height: CGFloat = 72
        let listHeight: CGFloat = 46
        let mediaPos = UserDefaults.standard.string(forKey: "mediaOverlayPosition") ?? "bottom"
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            progress: playbackProgress,
            barColor: actionColor,
            fillCenter: false,
            listHeight: listHeight,
            customWidth: width,
            customHeight: height,
            supportDragGesture: true,
            onDrag: { v in
                let newTime = Double(v) * mediaKeyManager.mediaDuration
                localElapsed = newTime
                mediaKeyManager.simulateSeek(to: newTime)
            },
            isExpandable: true,
            expandUpwards: mediaPos == "bottom",
            keepAliveId: "media",
            baseContent: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: actionIcon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if mediaKeyManager.mediaDuration > 0 {
                            HStack(spacing: 4) {
                                Text(actionTitle)
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                Text("•")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .baselineOffset(1.0)
                                
                                Text("\(formatTime(localElapsed)) / \(formatTime(mediaKeyManager.mediaDuration))")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text(actionTitle)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                        }
                        
                        MarqueeText(text: actualTitle, font: .system(size: 13, weight: .bold, design: .rounded), foregroundColor: .primary)
                            
                        if !actualArtist.isEmpty {
                            MarqueeText(text: actualArtist, font: .system(size: 11, weight: .medium, design: .rounded), foregroundColor: .secondary)
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
            },
            expandedContent: {
                HStack(spacing: 32) {
                    Button(action: {
                        if isPreview { return }
                        if isPodcastOrBrowser {
                            let newTime = max(0, localElapsed - 10)
                            localElapsed = newTime
                            mediaKeyManager.simulateSeek(to: newTime)
                        } else {
                            mediaKeyManager.simulatePrevious()
                        }
                    }) {
                        Image(systemName: isPodcastOrBrowser ? "gobackward.10" : "backward.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        if isPreview { return }
                        mediaKeyManager.simulatePlayPause()
                    }) {
                        Image(systemName: actualIsPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        if isPreview { return }
                        if isPodcastOrBrowser {
                            let newTime = min(mediaKeyManager.mediaDuration, localElapsed + 10)
                            localElapsed = newTime
                            mediaKeyManager.simulateSeek(to: newTime)
                        } else {
                            mediaKeyManager.simulateNext()
                        }
                    }) {
                        Image(systemName: isPodcastOrBrowser ? "goforward.10" : "forward.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        )

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
    
    private func formatTime(_ time: Double) -> String {
        guard !time.isNaN && !time.isInfinite else { return "0:00" }
        let totalSeconds = Int(time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
