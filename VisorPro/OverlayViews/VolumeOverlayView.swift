import SwiftUI

struct VolumeOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("volumeFillCenter") private var volumeFillCenter: Bool = true
    @State private var animatedVolumeProgress: CGFloat = 0.0
    var isPreview: Bool = false
    
    private var actualVolume: Int {
        isPreview ? 65 : mediaKeyManager.currentVolume
    }
    
    private var actualIsMuted: Bool {
        isPreview ? false : mediaKeyManager.isMuted
    }
    
    private var iconName: String {
        if actualIsMuted || actualVolume == 0 {
            return "speaker.slash.fill"
        } else if actualVolume < 33 {
            return "speaker.wave.1.fill"
        } else if actualVolume < 66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
    @State private var isExpanded: Bool = false
    @State private var isHovering: Bool = false
    @State private var availableDevices: [(id: UInt32, name: String)] = []
    

    @State private var expandedKeepAliveTimer: Timer? = nil

    var body: some View {
        let currentDevices = isPreview ? [(id: UInt32(1), name: "MacBook Pro Speakers"), (id: UInt32(2), name: "AirPods Pro")] : availableDevices
        let maxListHeight: CGFloat = 160
        let listHeight = currentDevices.isEmpty ? 0 : min(CGFloat(currentDevices.count * 40 + 10), maxListHeight)
        let volPos = UserDefaults.standard.string(forKey: "volumeOverlayPosition") ?? "bottom"
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            progress: animatedVolumeProgress,
            barColor: .blue,
            fillCenter: volumeFillCenter,
            isMuted: actualIsMuted,
            listHeight: listHeight,
            supportDragGesture: true,
            onDrag: { v in
                mediaKeyManager.setVolume(to: Int(v * 100))
            },
            onLeftTap: {
                if !isPreview { mediaKeyManager.toggleVolumeMute() }
            },
            onRightTap: {
                if !isExpanded {
                    availableDevices = VolumeManager.shared.getAvailableOutputDevices()
                }
            },
            expandUpwards: volPos == "bottom",
            baseContent: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(actualIsMuted ? .secondary : .primary)
                        .frame(width: 26, height: 24)
                    
                    MarqueeText(text: actualIsMuted ? "Muted" : mediaKeyManager.currentAudioDeviceName, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                    
                    Spacer(minLength: 8)
                    
                    AnimatablePercentageText(progress: animatedVolumeProgress, isTopTitle: true, color: .primary, isPluggedIn: false, customText: "%d%")
                }
                .padding(.horizontal, 16 + 4 + 3) // 16 + trackPadding + innerPadding
            },
            expandedContent: {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(currentDevices, id: \.id) { device in
                            DeviceRowView(
                                device: device,
                                isCurrent: isPreview ? (device.id == 2) : device.name == mediaKeyManager.currentAudioDeviceName,
                                onSelect: {
                                    if !isPreview {
                                        VolumeManager.shared.setOutputDevice(id: device.id)
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                            isExpanded = false
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.top, 2)
                    .padding(.bottom, 8)
                    .padding(.horizontal, 4 + 3 + 4)
                }
            }
        )
        .frame(width: 260, height: isExpanded ? 56 + listHeight : 56, alignment: .top)

        .padding(20)
        .onHoverExact { hovering in
            isHovering = hovering
            if !isPreview {
                mediaKeyManager.keepAlive(for: "volume", isHovering: hovering || isExpanded)
            }
        }
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                expandedKeepAliveTimer?.invalidate()
                expandedKeepAliveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    DispatchQueue.main.async {
                        if !isPreview { mediaKeyManager.keepAlive(for: "volume", isHovering: true) }
                    }
                }
            } else {
                expandedKeepAliveTimer?.invalidate()
                expandedKeepAliveTimer = nil
                if !isPreview {
                    mediaKeyManager.keepAlive(for: "volume", isHovering: isHovering)
                }
            }
        }
        .applyTheme(mediaKeyManager.overlayTheme)
        .onAppear {
            if isPreview {
                animatedVolumeProgress = 0.2
                withAnimation(.easeInOut(duration: 1.0)) {
                    animatedVolumeProgress = 0.65
                }
            } else {
                let targetProgress = CGFloat(actualVolume) / 100.0
                animatedVolumeProgress = targetProgress
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    animatedVolumeProgress = targetProgress
                }
            }
        }
        .onChange(of: actualVolume) { _, newValue in
            let targetProgress = CGFloat(newValue) / 100.0
            withAnimation(.easeOut(duration: 0.25)) {
                animatedVolumeProgress = targetProgress
            }
        }
        .onChange(of: actualIsMuted) { _, _ in
            let targetProgress = CGFloat(actualVolume) / 100.0
            withAnimation(.easeOut(duration: 0.25)) {
                animatedVolumeProgress = targetProgress
            }
        }
        .onChange(of: mediaKeyManager.audioDevicesChanged) { _, _ in
            if isExpanded {
                availableDevices = VolumeManager.shared.getAvailableOutputDevices()
            }
        }
        .onDisappear {
            expandedKeepAliveTimer?.invalidate()
            expandedKeepAliveTimer = nil
            mediaKeyManager.keepAlive(for: "volume", isHovering: false)
        }
    }
}
