import SwiftUI

struct VolumeOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @EnvironmentObject var overlayState: OverlayStateRelay
    @AppStorage("volumeFillCenter") private var volumeFillCenter: Bool = false
    @AppStorage("volumeAllowExpansion") private var volumeAllowExpansion: Bool = true
    @AppStorage("volumeAllowInteractivity") private var volumeAllowInteractivity: Bool = true
    @State private var _animatedVolumeProgress: CGFloat? = nil
    private var animatedVolumeProgress: CGFloat {
        _animatedVolumeProgress ?? (CGFloat(actualVolume) / 100.0)
    }
    @State private var previewVolume: Int = 65
    @State private var previewIsMuted: Bool = false
    @State private var previewSelectedDevice: UInt32 = 2
    var isPreview: Bool = false
    
    private var actualVolume: Int {
        isPreview ? previewVolume : overlayState.currentVolume
    }
    
    private var actualDeviceName: String {
        if isPreview {
            return previewSelectedDevice == 1 ? "MacBook Pro Speakers" : "AirPods Pro"
        } else {
            return overlayState.currentAudioDeviceName
        }
    }
    
    private var actualIsMuted: Bool {
        isPreview ? previewIsMuted : overlayState.isMuted
    }
    
    private var actionColor: Color {
        actualIsMuted ? .secondary : OverlayColorManager.shared.getOverlayColor(for: "colorOnVolume", defaultColor: .blue)
    }
    
    private var iconName: String {
        VolumeOverlayView.iconForAudioDevice(
            name: actualDeviceName,
            volume: actualVolume,
            isMuted: actualIsMuted
        )
    }
    
    // MARK: - Audio Device Icon Helpers
    
    static func isSystemSpeakers(name: String) -> Bool {
        let lower = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.isEmpty { return true }
        
        // Explicit internal / built-in keywords
        if lower.contains("internal speaker") || lower.contains("internal speakers") { return true }
        if lower.contains("built-in") || lower.contains("builtin") { return true }
        if lower.contains("wbudowane") || lower.contains("wewnętrzne") { return true }
        
        // Mac model speakers across multiple system languages (English, Polish, etc.)
        let isMacModel = lower.contains("macbook") || lower.contains("imac") || lower.contains("mac mini") || lower.contains("mac studio") || lower.contains("mac pro") || lower.contains("maca")
        let isSpeakerWord = lower.contains("speaker") || lower.contains("głośnik") || lower.contains("haut-parleur") || lower.contains("lautsprecher") || lower.contains("altavoz")
        
        if isMacModel && isSpeakerWord {
            return true
        }
        
        // Standalone generic names
        if lower == "speakers" || lower == "głośniki" || lower == "internal" || lower == "wbudowane" {
            return true
        }
        
        return false
    }
    
    static func iconForAudioDevice(name: String, volume: Int, isMuted: Bool) -> String {
        if isSystemSpeakers(name: name) {
            if isMuted || volume == 0 {
                return "speaker.slash.fill"
            } else if volume < 33 {
                return "speaker.wave.1.fill"
            } else if volume < 66 {
                return "speaker.wave.2.fill"
            } else {
                return "speaker.wave.3.fill"
            }
        }
        
        return iconForExternalDevice(name: name)
    }
    
    static func iconForExternalDevice(name: String) -> String {
        let lower = name.lowercased()
        
        // 1. AirPods Max (Over-ear)
        if lower.contains("airpods max") || (lower.contains("airpod") && (lower.contains("max") || lower.contains("nauszne") || lower.contains("over-ear"))) {
            return "airpodsmax"
        }
        
        // 2. AirPods Pro (In-ear with silicon tips)
        if lower.contains("airpods pro") || lower.contains("airpod pro") {
            return "airpodspro"
        }
        
        // 3. Regular AirPods (Earbuds)
        if lower.contains("airpod") {
            return "airpods"
        }
        
        // 4. Beats
        if lower.contains("beats") {
            if lower.contains("fit") || lower.contains("bud") || lower.contains("flex") || lower.contains("powerbeats") || lower.contains("ear") {
                return "beats.earphones"
            }
            return "beats.headphones"
        }
        
        // 5. In-ear Earbuds (Galaxy Buds, Pixel Buds, FreeBuds, Sony WF, etc.)
        if lower.contains("bud") || lower.contains("buds") || lower.contains("earbud") || lower.contains("earbuds") || lower.contains("earphone") || lower.contains("earphones") || lower.contains("airdot") || lower.contains("airdots") || lower.contains("in-ear") || lower.contains("douszne") || lower.contains("wf-1000") || lower.contains("wf-c") || lower.contains("linkbuds") {
            return "earbuds"
        }
        
        // 6. Over-ear / On-ear Headphones (Sony WH, Bose QC, Sennheiser, Marshall, etc.)
        if lower.contains("headphone") || lower.contains("headphones") || lower.contains("headset") || lower.contains("słuchawk") || lower.contains("wh-1000") || lower.contains("wh-ch") || lower.contains("quietcomfort") || lower.contains("qc35") || lower.contains("qc45") || lower.contains("qc ultra") || lower.contains("momentum") || lower.contains("major") || lower.contains("anc") || lower.contains("over-ear") || lower.contains("on-ear") || lower.contains("arctis") || lower.contains("kraken") || lower.contains("blackshark") || lower.contains("cloud") {
            return "headphones"
        }
        
        // 7. HomePod
        if lower.contains("homepod") {
            return "homepod.fill"
        }
        
        // 8. External Speakers & Soundbars (JBL, Bose SoundLink, Sonos, Marshall, etc.)
        if lower.contains("speaker") || lower.contains("speakers") || lower.contains("głośnik") || lower.contains("soundbar") || lower.contains("soundlink") || lower.contains("flip") || lower.contains("charge") || lower.contains("boombox") || lower.contains("xtreme") || lower.contains("clip") || lower.contains("megaboom") || lower.contains("wonderboom") || lower.contains("emberton") || lower.contains("acton") || lower.contains("stanmore") || lower.contains("woburn") || lower.contains("sonos") || lower.contains("soundcore") || lower.contains("anker") || lower.contains("jbl") || lower.contains("audioengine") || lower.contains("harman") || lower.contains("kardon") || lower.contains("onyx") || lower.contains("echo") || lower.contains("alexa") || lower.contains("nest audio") || lower.contains("hifi") {
            return "hifispeaker.fill"
        }
        
        // 9. Displays / TVs
        if lower.contains("tv") || lower.contains("television") || lower.contains("apple tv") {
            return "tv.fill"
        }
        if lower.contains("display") || lower.contains("monitor") || lower.contains("ultrafine") || lower.contains("studio display") || lower.contains("pro display") || lower.contains("dell") || lower.contains("lg") || lower.contains("samsung") || lower.contains("benq") || lower.contains("asus") || lower.contains("acer") || lower.contains("hdmi") || lower.contains("displayport") {
            return "display"
        }
        
        // 10. Default fallback for other external audio devices
        return "headphones"
    }
    @State private var isExpanded: Bool = false
    @State private var availableDevices: [(id: UInt32, name: String)] = []

    var body: some View {
        let currentDevices = isPreview ? [(id: UInt32(1), name: "MacBook Pro Speakers"), (id: UInt32(2), name: "AirPods Pro")] : availableDevices
        let volPos = MediaKeyManager.shared.getOverlayPosition(for: "volumeOverlayPosition")
        let calcHeight: CGFloat = currentDevices.isEmpty ? 18 : 18 + CGFloat(currentDevices.count * 32 + (currentDevices.count - 1) * 4)
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            progress: animatedVolumeProgress,
            barColor: OverlayColorManager.shared.getOverlayColor(for: "colorOnVolume", defaultColor: .blue),
            fillCenter: volumeFillCenter,
            isMuted: actualIsMuted,
            supportDragGesture: volumeAllowInteractivity,
            onDrag: { v in
                if isPreview {
                    previewVolume = Int(v * 100)
                    _animatedVolumeProgress = v
                } else {
                    mediaKeyManager.setVolume(to: Int(v * 100))
                }
            },
            onLeftTap: {
                if isPreview {
                    previewIsMuted.toggle()
                } else {
                    mediaKeyManager.toggleVolumeMute()
                }
            },
            onRightTap: nil,
            onSimpleTap: nil,
            isExpandable: volumeAllowExpansion,
            expandUpwards: volPos.hasPrefix("bottom"),
            keepAliveId: "volume",
            disableTimeoutMode: true,
            fixedExpandedHeight: calcHeight,
            minimalText: actualIsMuted ? "Muted" : "\(actualVolume)%",
            minimalIcon: iconName,
            baseContent: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(actualIsMuted ? .secondary : .primary)
                        .frame(width: 26, height: 24)
                    
                    MarqueeText(text: actualIsMuted ? "Muted" : actualDeviceName, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                        .id(actualIsMuted ? "muted" : actualDeviceName)
                    
                    Spacer(minLength: 8)
                    
                    AnimatablePercentageText(progress: animatedVolumeProgress, isTopTitle: true, color: .primary, isPluggedIn: false, customText: "%d%")
                }
                .padding(.leading, 23)
                .padding(.trailing, 23)
                .frame(maxWidth: .infinity, alignment: .leading)
            },
            expandedContent: {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(currentDevices, id: \.id) { device in
                        let isDeviceCurrent = isPreview ? (device.id == previewSelectedDevice) : device.name == overlayState.currentAudioDeviceName
                        let deviceIcon = VolumeOverlayView.isSystemSpeakers(name: device.name) ? "speaker.wave.2.fill" : VolumeOverlayView.iconForExternalDevice(name: device.name)
                        DeviceRowView(
                            device: device,
                            isCurrent: isDeviceCurrent,
                            tintColor: actionColor,
                            icon: deviceIcon,
                            onSelect: {
                                if isPreview {
                                    previewSelectedDevice = device.id
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isExpanded = false
                                    }
                                } else {
                                    VolumeManager.shared.setOutputDevice(id: device.id)
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isExpanded = false
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.top, 2)
                .padding(.horizontal, 4 + 3 + 4)
            }
        )


        .onAppear {
            if !isPreview {
                availableDevices = VolumeManager.shared.getAvailableOutputDevices()
            }
            if isPreview {
                _animatedVolumeProgress = 0.2
                withAnimation(.easeInOut(duration: 1.0)) {
                    _animatedVolumeProgress = 0.65
                }
            } else {
                _animatedVolumeProgress = CGFloat(actualVolume) / 100.0
            }
        }
        .onChange(of: actualVolume) { _, newValue in
            let targetProgress = CGFloat(newValue) / 100.0
            withAnimation(.easeOut(duration: 0.15)) {
                _animatedVolumeProgress = targetProgress
            }
        }
        .onChange(of: actualIsMuted) { _, _ in
            let targetProgress = CGFloat(actualVolume) / 100.0
            withAnimation(.easeOut(duration: 0.15)) {
                _animatedVolumeProgress = targetProgress
            }
        }
        .onChange(of: overlayState.audioDevicesChanged) { _, _ in
            if !isPreview {
                availableDevices = VolumeManager.shared.getAvailableOutputDevices()
            }
        }
    }
}
