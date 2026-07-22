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
    @State private var expandedKeepAliveTimer: Timer? = nil
    
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
        let trackPadding: CGFloat = 4
        let innerPadding: CGFloat = 3
        let trackHeight = height - (trackPadding * 2)
        let trackWidth = width - (trackPadding * 2)
        let innerRadius: CGFloat = (height / 2) - trackPadding
        
        
        VStack(spacing: 0) {
            VStack(spacing: 0) {
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
                .padding(.horizontal, 12)
                .frame(width: trackWidth, height: trackHeight)
                .padding(.leading, trackPadding + innerPadding)
            }
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if isPreview { return }
                        
                        if isDragging {
                            let percent = max(0, min(1, value.location.x / width))
                            let newTime = Double(percent) * mediaKeyManager.mediaDuration
                            localElapsed = newTime
                            mediaKeyManager.simulateSeek(to: newTime)
                        } else {
                            let moved = abs(value.translation.width) >= 8 || abs(value.translation.height) >= 8
                            if moved {
                                holdTimer?.invalidate()
                                holdTimer = nil
                                isDragging = true
                                let percent = max(0, min(1, value.location.x / width))
                                let newTime = Double(percent) * mediaKeyManager.mediaDuration
                                localElapsed = newTime
                                mediaKeyManager.simulateSeek(to: newTime)
                            } else if holdTimer == nil {
                                let timer = Timer(timeInterval: 0.2, repeats: false) { _ in
                                    DispatchQueue.main.async { 
                                        isDragging = true
                                        let percent = max(0, min(1, value.location.x / width))
                                        let newTime = Double(percent) * mediaKeyManager.mediaDuration
                                        localElapsed = newTime
                                        mediaKeyManager.simulateSeek(to: newTime)
                                    }
                                }
                                RunLoop.main.add(timer, forMode: .common)
                                holdTimer = timer
                            }
                        }
                    }
                    .onEnded { value in
                        if isPreview { return }
                        holdTimer?.invalidate()
                        holdTimer = nil
                        
                        if isDragging {
                            isDragging = false
                        } else {
                            let moved = abs(value.translation.width) >= 8 || abs(value.translation.height) >= 8
                            if !moved {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                    isExpanded.toggle()
                                }
                            }
                        }
                    }
            )
            
            HStack(spacing: 32) {
                Button(action: {
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
                
                Button(action: { mediaKeyManager.simulatePlayPause() }) {
                    Image(systemName: actualIsPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Button(action: {
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
            .frame(width: width, height: isExpanded ? listHeight : 0, alignment: .top)
            .padding(.top, isExpanded ? 4 : 0)
            .clipped()
            .opacity(isExpanded ? 1 : 0)
        }
        .frame(width: width, height: isExpanded ? height + listHeight : height, alignment: .top)
        .background(
            ZStack {
                ZStack {
                    ActiveVisualEffectView()
                        .clipShape(RoundedRectangle(cornerRadius: height / 2, style: .continuous))
                    
                    RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.15), lineWidth: innerPadding)
                        .frame(width: trackWidth, height: isExpanded ? height + listHeight - (trackPadding * 2) : trackHeight)
                }
                .frame(width: width, height: isExpanded ? height + listHeight : height)
                
                Group {
                    RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                        .strokeBorder(actionColor.opacity(0.85), lineWidth: innerPadding)
                        .frame(width: trackWidth, height: isExpanded ? height + listHeight - (trackPadding * 2) : trackHeight)
                }
                .mask(
                    HStack(spacing: 0) {
                        Rectangle()
                            .frame(width: max(0, trackWidth * playbackProgress))
                        Spacer(minLength: 0)
                    }
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: playbackProgress)
                
                // Wewnętrzna warstwa (3D) taka sama jak w nakładce głośności
                ZStack {
                    ActiveVisualEffectView()
                        .clipShape(RoundedRectangle(cornerRadius: (height / 2) - trackPadding - innerPadding, style: .continuous))
                    
                    RoundedRectangle(cornerRadius: (height / 2) - trackPadding - innerPadding, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                        .blendMode(.overlay)
                }
                .padding(trackPadding + innerPadding)
            }
        )
        .contentShape(RoundedRectangle(cornerRadius: height / 2, style: .continuous))
        .onHover { isHovering in
            if !isPreview {
                mediaKeyManager.keepAlive(for: "media", isHovering: isHovering || isExpanded)
            }
        }
        .frame(width: width)
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
        .onChange(of: isExpanded) { expanded in
            if expanded {
                expandedKeepAliveTimer?.invalidate()
                expandedKeepAliveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    DispatchQueue.main.async {
                        if !isPreview { mediaKeyManager.keepAlive(for: "media", isHovering: true) }
                    }
                }
            } else {
                expandedKeepAliveTimer?.invalidate()
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
