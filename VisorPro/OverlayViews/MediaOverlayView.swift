import SwiftUI
import Combine

struct MediaOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("mediaAllowExpansion") private var mediaAllowExpansion: Bool = true
    @AppStorage("mediaAllowInteractivity") private var mediaAllowInteractivity: Bool = true
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
        case "end": return .secondary
        default: return .pink
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
            return "music.note"
        } else if bundle.contains("music") {
            return "music.note"
        } else if bundle.contains("podcasts") {
            return "mic.fill"
        } else if bundle.contains("safari") {
            return "safari.fill"
        } else if bundle.contains("chrome") || bundle.contains("arc") || bundle.contains("edge") || bundle.contains("brave") {
            return "network"
        } else if bundle.contains("tv") || bundle.contains("vlc") || bundle.contains("iina") || bundle.contains("quicktime") || bundle.contains("mpv") {
            return "play.tv.fill"
        } else {
            return "play.circle.fill"
        }
    }
    
    @State private var isExpanded: Bool = false
    @State private var isDragging: Bool = false
    @State private var dragStartElapsed: Double = 0.0
    @State private var dragStartX: CGFloat = 0.0
    @State private var holdTimer: Timer? = nil
    

    var body: some View {
        let width: CGFloat = 260
        let height: CGFloat = 72
        let mediaPos = MediaKeyManager.shared.getOverlayPosition(for: "mediaOverlayPosition")
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            progress: playbackProgress,
            barColor: actionColor,
            fillCenter: false,
            customWidth: width,
            customHeight: height,
            supportDragGesture: mediaAllowInteractivity,
            onDrag: { v in
                let newTime = Double(v) * mediaKeyManager.mediaDuration
                localElapsed = newTime
                mediaKeyManager.simulateSeek(to: newTime)
            },
            onLeftTap: {
                if !isPreview {
                    mediaKeyManager.openMediaApp()
                }
            },
            isExpandable: mediaAllowExpansion,
            expandUpwards: mediaPos.hasPrefix("bottom"),
            keepAliveId: "media",
            disableTimeoutMode: true,
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
                HStack(spacing: 20) {
                    let skipStr = Int(mediaKeyManager.mediaSkipDuration)
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0).onEnded { _ in
                                if isPreview { return }
                                mediaKeyManager.simulatePrevious()
                            }
                        )

                    ZStack {
                        Image(systemName: "gobackward")
                            .font(.system(size: 18, weight: .semibold))
                        Text("\(skipStr)")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .offset(x: 0.4, y: 1.0)
                    }
                    .foregroundColor(.primary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0).onEnded { _ in
                            if isPreview { return }
                            let skip = mediaKeyManager.mediaSkipDuration
                            let newTime = max(0, localElapsed - skip)
                            localElapsed = newTime
                            mediaKeyManager.simulateSeek(to: newTime)
                        }
                    )
                    
                    Image(systemName: actualIsPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0).onEnded { _ in
                                if isPreview { return }
                                mediaKeyManager.simulatePlayPause()
                            }
                        )
                    
                    ZStack {
                        Image(systemName: "goforward")
                            .font(.system(size: 18, weight: .semibold))
                        Text("\(skipStr)")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .offset(x: 0.1, y: 1.0)
                    }
                    .foregroundColor(.primary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0).onEnded { _ in
                            if isPreview { return }
                            let skip = mediaKeyManager.mediaSkipDuration
                            let newTime = min(mediaKeyManager.mediaDuration, localElapsed + skip)
                            localElapsed = newTime
                            mediaKeyManager.simulateSeek(to: newTime)
                        }
                    )
                    
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0).onEnded { _ in
                                if isPreview { return }
                                mediaKeyManager.simulateNext()
                            }
                        )
                }
            }
        )
        .id(mediaKeyManager.mediaEventId)
        .onAppear {
            localElapsed = mediaKeyManager.mediaElapsedTime
        }
        .onChange(of: mediaKeyManager.mediaElapsedTime) { oldValue, newValue in
            localElapsed = newValue
        }
        .onReceive(timer) { _ in
            if actualIsPlaying && actualAction != "end" {
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
