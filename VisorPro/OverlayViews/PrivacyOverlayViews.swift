import SwiftUI
import AVFoundation

struct MicWaveformView: View {
    @ObservedObject var monitor = MicLevelMonitor.shared
    var color: Color
    var isMuted: Bool = false
    var isPreview: Bool = false
    var previewVolume: Float = 50.0
    
    @State private var previewLevels: [CGFloat] = Array(repeating: 0.1, count: 13)
    @State private var timer: Timer?
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<13, id: \.self) { index in
                let actualLevel: CGFloat = {
                    if isMuted { return 0.1 }
                    let raw = isPreview ? previewLevels[index] : (index < monitor.levels.count ? monitor.levels[index] : 0.1)
                    let volFactor = max(0.4, CGFloat(previewVolume) / 100.0)
                    return isPreview ? raw : max(0.1, raw * volFactor)
                }()
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 8, height: max(4, 40 * actualLevel))
                    .animation(.linear(duration: 0.1), value: actualLevel)
            }
        }
        .frame(height: 44)
        .onAppear {
            if isPreview {
                timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
                    let baseVolume = CGFloat(previewVolume) / 100.0
                    for i in 0..<previewLevels.count {
                        if isMuted {
                            previewLevels[i] = 0.1
                        } else {
                            let randomVal = CGFloat.random(in: 0.1...1.0)
                            previewLevels[i] = max(0.1, randomVal * baseVolume)
                        }
                    }
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

struct MicOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("micAllowExpansion") private var micAllowExpansion: Bool = true
    @AppStorage("micShowVisualizer") private var micShowVisualizer: Bool = false
    @State private var isExpanded: Bool = false
    @State private var currentVolume: Float = 50.0
    @State private var availableDevices: [(id: UInt32, name: String)] = []
    
    var isPreview: Bool = false
    var previewIsActive: Bool = true
    
    private var actualIsActive: Bool {
        if mediaKeyManager.isSwitchingMic { return true }
        return isPreview ? previewIsActive : mediaKeyManager.isMicActive
    }
    
    private var actionColor: Color {
        actualIsActive ? Color(red: 1.0, green: 0.65, blue: 0.0) : .secondary
    }
    
    private var actionTitle: String {
        actualIsActive ? "Microphone in Use" : "Microphone Off"
    }
    
    private func loadInitialVolume() {
        DispatchQueue.global(qos: .userInitiated).async {
            let (vol, isMuted) = VolumeManager.shared.getMicVolume()
            DispatchQueue.main.async {
                self.currentVolume = isMuted ? 0 : (vol * 100)
            }
        }
    }
    
    var body: some View {
        let currentDevices = isPreview ? [(id: UInt32(1), name: "MacBook Pro Microphone"), (id: UInt32(2), name: "External Mic")] : availableDevices
        let maxListHeight: CGFloat = 160
        let listHeight = currentDevices.isEmpty ? 0 : min(CGFloat(currentDevices.count * 40 + 10), maxListHeight)
        let displayedMicName = actualIsActive && !mediaKeyManager.activeMicName.isEmpty ? mediaKeyManager.activeMicName : mediaKeyManager.currentMicDeviceName
        let micPos = MediaKeyManager.shared.getOverlayPosition(for: "micOverlayPosition")
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            hasTimeoutProgress: true,
            timeoutEventId: mediaKeyManager.micEventId,
            barColor: actionColor,
            fillCenter: false,
            isMuted: currentVolume == 0,
            customWidth: 260,
            customHeight: 56,
            supportDragGesture: false,
            onRightTap: {
                if !isExpanded {
                    availableDevices = VolumeManager.shared.getAvailableInputDevices()
                }
            },
            isExpandable: actualIsActive && micAllowExpansion,
            expandUpwards: micPos == "bottom",
            keepAliveId: "mic",
            baseContent: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: actualIsActive ? "mic.fill" : "mic.slash.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(actualIsActive ? .primary : .secondary)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(actionTitle)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        MarqueeText(text: isPreview ? "System Microphone" : (displayedMicName.isEmpty ? "Microphone" : displayedMicName), font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                    }
                    
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16)
            },
            expandedContent: {
                if isExpanded {
                    VStack(spacing: 0) {
                        if !mediaKeyManager.activeMicClientName.isEmpty {
                            VStack(spacing: 12) {
                                Divider()
                                    .padding(.horizontal, 16)
                                
                                HStack(spacing: 12) {
                                    // App Icon
                                    let path = mediaKeyManager.activeMicClientBundleID
                                    if !path.isEmpty {
                                        Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                                            .resizable()
                                            .frame(width: 32, height: 32)
                                    } else {
                                        Image(systemName: "app.fill")
                                            .resizable()
                                            .frame(width: 32, height: 32)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Used by:")
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundColor(.secondary)
                                        Text(mediaKeyManager.activeMicClientName)
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                            }
                            .padding(.top, 4)
                            .padding(.bottom, 12)
                        }
                        if !currentDevices.isEmpty {
                            ScrollView(showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(currentDevices, id: \.id) { device in
                                        DeviceRowView(
                                            device: device,
                                            isCurrent: isPreview ? (device.id == 1) : device.name == mediaKeyManager.currentMicDeviceName,
                                            tintColor: actionColor,
                                            onSelect: {
                                                if !isPreview {
                                                    mediaKeyManager.startMicSwitchingBuffer()
                                                    mediaKeyManager.currentMicDeviceName = device.name
                                                    VolumeManager.shared.setInputDevice(id: device.id)
                                                    MicLevelMonitor.shared.handleDeviceSwitch()
                                                    
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                                        loadInitialVolume()
                                                    }
                                                }
                                            }
                                        )
                                    }
                                }
                                .padding(.top, 2)
                                
                                .padding(.horizontal, 4 + 3 + 4)
                            }
                            .frame(height: listHeight)
                            
                            Divider()
                                .padding(.horizontal, 16)
                        }

                        VStack(spacing: 12) {
                            if micShowVisualizer {
                                MicWaveformView(color: actionColor, isMuted: currentVolume == 0, isPreview: isPreview, previewVolume: currentVolume)
                            }
                            
                            HStack(spacing: 12) {
                                Image(systemName: currentVolume == 0 ? "mic.slash.fill" : "mic.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 12))
                                
                                Slider(value: Binding(
                                    get: { currentVolume },
                                    set: { newValue in
                                        currentVolume = newValue
                                        if !isPreview {
                                            VolumeManager.shared.setMicVolume(volume: Float(newValue) / 100.0, mute: newValue == 0)
                                        }
                                    }
                                ), in: 0...100)
                                .tint(actionColor)
                                .accentColor(actionColor)
                                .environment(\.controlActiveState, .active)
                            }
                            .padding(.horizontal, 8)
                        }
                        .padding(.top, currentDevices.isEmpty ? 4 : 12)
                        
                        .padding(.horizontal, 16)
                        .onAppear {
                            if !isPreview {
                                loadInitialVolume()
                            }
                        }
                    }
                } else {
                    EmptyView()
                }
            }
        )
        .onAppear {
            if isExpanded && actualIsActive && !isPreview && micShowVisualizer {
                MicLevelMonitor.shared.startMonitoring()
            }
        }
        .onChange(of: isExpanded) { _, expanded in
            if !isPreview {
                mediaKeyManager.isMicExpanded = expanded
                if expanded {
                    availableDevices = VolumeManager.shared.getAvailableInputDevices()
                    if micShowVisualizer {
                        MicLevelMonitor.shared.startMonitoring()
                    }
                    loadInitialVolume()
                } else {
                    MicLevelMonitor.shared.stopMonitoring(immediately: false)
                }
            }
        }
        .onChange(of: actualIsActive) { _, isActive in
            if mediaKeyManager.isSwitchingMic { return }
            if isActive && isExpanded && !isPreview && micShowVisualizer {
                MicLevelMonitor.shared.startMonitoring()
            } else if !isActive && isExpanded {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    isExpanded = false
                }
            }
        }
        .onChange(of: micShowVisualizer) { _, show in
            if !isPreview && isExpanded && actualIsActive {
                if show {
                    MicLevelMonitor.shared.startMonitoring()
                } else {
                    MicLevelMonitor.shared.stopMonitoring(immediately: true)
                }
            }
        }
        .onChange(of: mediaKeyManager.audioDevicesChanged) { _, _ in
            if isExpanded && !isPreview {
                availableDevices = VolumeManager.shared.getAvailableInputDevices()
                loadInitialVolume()
            }
        }
        .onDisappear {
            if !isPreview {
                mediaKeyManager.isMicExpanded = false
                if !mediaKeyManager.isMicActive {
                    MicLevelMonitor.shared.stopMonitoring(immediately: true)
                }
            }
        }

    }
}

struct CameraEffectButton: View {
    var title: String
    var systemImage: String
    @Binding var isOn: Bool
    var activeColor: Color
    
    @State private var isHovering: Bool = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                isOn.toggle()
            }
        }) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isOn ? activeColor : Color.secondary.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isOn ? .white : .primary.opacity(0.8))
                }
                
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(isOn ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 26, alignment: .top)
            }
            .frame(width: 68)
            .padding(.vertical, 6)
            .background(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

struct CameraOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("cameraAllowExpansion") private var cameraAllowExpansion: Bool = true
    @State private var isExpanded: Bool = false
    @AppStorage("cam_portrait") private var isPortraitEnabled = false
    @AppStorage("cam_studio") private var isStudioLightEnabled = false
    @AppStorage("cam_reactions") private var isReactionsEnabled = false
    
    var isPreview: Bool = false
    var previewIsActive: Bool = true
    
    private var actualIsActive: Bool {
        isPreview ? previewIsActive : mediaKeyManager.isCameraActive
    }
    
    private var actionColor: Color {
        actualIsActive ? .green : .secondary
    }
    
    private var actionTitle: String {
        actualIsActive ? "Camera in Use" : "Camera Off"
    }
    
    var body: some View {
        
        
        let camPos = MediaKeyManager.shared.getOverlayPosition(for: "cameraOverlayPosition")
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            hasTimeoutProgress: true,
            timeoutEventId: mediaKeyManager.cameraEventId,
            barColor: actionColor,
            fillCenter: false,
            isMuted: false,
            customWidth: 260,
            customHeight: 56,
            supportDragGesture: false,
            isExpandable: actualIsActive && cameraAllowExpansion,
            expandUpwards: camPos == "bottom",
            keepAliveId: "camera",
            baseContent: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: actualIsActive ? "video.fill" : "video.slash.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(actualIsActive ? .primary : .secondary)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(actionTitle)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        MarqueeText(text: isPreview ? "FaceTime HD Camera" : (mediaKeyManager.activeCameraName.isEmpty ? "Camera" : mediaKeyManager.activeCameraName), font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                    }
                    
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16)
            },
            expandedContent: {
                if isExpanded {
                    VStack(spacing: 12) {
                        if isPreview || !mediaKeyManager.activeCameraClientName.isEmpty {
                            VStack(spacing: 12) {
                                Divider()
                                    .padding(.horizontal, 16)
                                
                                HStack(spacing: 12) {
                                    // App Icon
                                    let path = isPreview ? "/System/Applications/FaceTime.app" : mediaKeyManager.activeCameraClientBundleID
                                    if !path.isEmpty {
                                        Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                                            .resizable()
                                            .frame(width: 32, height: 32)
                                    } else {
                                        Image(systemName: isPreview ? "video.fill" : "app.fill")
                                            .resizable()
                                            .frame(width: 32, height: 32)
                                            .foregroundColor(isPreview ? .green : .secondary)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Used by:")
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundColor(.secondary)
                                        Text(isPreview ? "FaceTime" : mediaKeyManager.activeCameraClientName)
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                
                                if isPreview || mediaKeyManager.activeCameraClientPID != nil {
                                    Button(action: {
                                        if !isPreview, let pid = mediaKeyManager.activeCameraClientPID {
                                            let process = Process()
                                            process.launchPath = "/bin/kill"
                                            process.arguments = ["-9", "\(pid)"]
                                            try? process.run()
                                            
                                            withAnimation {
                                                isExpanded = false
                                            }
                                        }
                                    }) {
                                        Text("Kill process")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(Color.primary.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.top, 4)
                        } else {
                            Text("No application information")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .padding(.top, 16)
                                .padding(.bottom, 8)
                        }
                    }
                } else {
                    EmptyView()
                }
            }
        )

                .onChange(of: isExpanded) { _, expanded in
            mediaKeyManager.isCameraExpanded = expanded
        }
        .onChange(of: actualIsActive) { _, isActive in
            if !isActive && isExpanded {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    isExpanded = false
                }
            }
        }
        .onDisappear {
            if isExpanded {
                mediaKeyManager.isCameraExpanded = false
            }
            mediaKeyManager.keepAlive(for: "camera", isHovering: false)
        }
    }
}

struct LocationOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @State private var isExpanded: Bool = false
    
    var isPreview: Bool = false
    var previewIsActive: Bool = true
    
    private var actualIsActive: Bool {
        isPreview ? previewIsActive : mediaKeyManager.isLocationActive
    }
    
    private var actionColor: Color {
        actualIsActive ? Color(red: 0.0, green: 0.45, blue: 0.9) : .secondary
    }
    
    private var actionTitle: String {
        actualIsActive ? "Location in Use" : "Location Off"
    }
    
    var body: some View {
        
        let locPos = MediaKeyManager.shared.getOverlayPosition(for: "locationOverlayPosition")
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            hasTimeoutProgress: true,
            timeoutEventId: mediaKeyManager.locationEventId,
            barColor: actionColor,
            fillCenter: false,
            isMuted: false,
            customWidth: 260,
            customHeight: 56,
            supportDragGesture: false,
            isExpandable: false,
            expandUpwards: locPos == "bottom",
            keepAliveId: "location",
            baseContent: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: actualIsActive ? "location.fill" : "location.slash.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(actualIsActive ? .primary : .secondary)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(actionTitle)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        let displayedName = mediaKeyManager.activeLocationAppName.isEmpty ? "Location Services" : mediaKeyManager.activeLocationAppName
                        MarqueeText(text: isPreview ? "System Location" : displayedName, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                    }
                    
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16)
            },
            expandedContent: {
                EmptyView()
            }
        )
                .onDisappear {
            mediaKeyManager.keepAlive(for: "location", isHovering: false)
        }
    }
}
