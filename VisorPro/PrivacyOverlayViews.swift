import SwiftUI
import AVFoundation

struct MicWaveformView: View {
    @ObservedObject var monitor = MicLevelMonitor.shared
    var color: Color
    var isMuted: Bool = false
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<monitor.levels.count, id: \.self) { index in
                let level = isMuted ? 0.1 : monitor.levels[index]
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 8, height: max(4, 40 * level))
                    .animation(.linear(duration: 0.1), value: level)
            }
        }
        .frame(height: 44)
    }
}

struct MicOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @State private var isHovering: Bool = false
    @State private var isExpanded: Bool = false
    @State private var currentVolume: Float = 50.0
    
    var isPreview: Bool = false
    var previewIsActive: Bool = true
    
    private var actualIsActive: Bool {
        isPreview ? previewIsActive : mediaKeyManager.isMicActive
    }
    
    private var actionColor: Color {
        actualIsActive ? .green : .secondary
    }
    
    private var actionTitle: String {
        actualIsActive ? "Microphone On" : "Microphone Off"
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
        let trackWidth: CGFloat = 260 - 8 // width - 2*trackPadding
        let expandedHeight: CGFloat = 100
        let displayedMicName = actualIsActive && !mediaKeyManager.activeMicName.isEmpty ? mediaKeyManager.activeMicName : mediaKeyManager.currentMicDeviceName
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            progress: 1.0,
            customProgressMask: AnyView(
                TimeoutProgressBar(trackWidth: trackWidth, isHovering: isHovering || isExpanded, initialDuration: MediaKeyManager.notificationDuration, hoverOutDuration: MediaKeyManager.notificationDuration)
                    .id(mediaKeyManager.micEventId)
            ),
            barColor: actionColor,
            fillCenter: false,
            isMuted: currentVolume == 0,
            listHeight: expandedHeight,
            customWidth: 260,
            supportDragGesture: false,
            onRightTap: nil,
            onSimpleTap: {
                if !isPreview {
                    mediaKeyManager.keepAlive(for: "mic", isHovering: true)
                }
            },
            isExpandable: actualIsActive,
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
                .padding(.horizontal, 16 + 4 + 3)
            },
            expandedContent: {
                if isExpanded {
                    VStack(spacing: 12) {
                        MicWaveformView(color: actionColor, isMuted: currentVolume == 0)
                        
                        HStack(spacing: 12) {
                            Image(systemName: currentVolume == 0 ? "mic.slash.fill" : "mic.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                            
                            Slider(value: Binding(
                                get: { currentVolume },
                                set: { newValue in
                                    currentVolume = newValue
                                    VolumeManager.shared.setMicVolume(volume: Float(newValue) / 100.0, mute: newValue == 0)
                                }
                            ), in: 0...100)
                        }
                        .padding(.horizontal, 8)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                    .padding(.horizontal, 16)
                    .onAppear {
                        loadInitialVolume()
                    }
                } else {
                    EmptyView()
                }
            }
        )
        .frame(width: 260, height: isExpanded ? 56 + expandedHeight : 56, alignment: .top)
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(20)
        .onChange(of: isExpanded) { expanded in
            mediaKeyManager.isMicExpanded = expanded
            if expanded {
                MicLevelMonitor.shared.startMonitoring()
                loadInitialVolume()
                mediaKeyManager.keepAlive(for: "mic", isHovering: true)
            } else {
                MicLevelMonitor.shared.stopMonitoring()
                if !isHovering {
                    mediaKeyManager.keepAlive(for: "mic", isHovering: false)
                }
            }
        }
        .onHoverExact { hovering in
            if !isPreview {
                isHovering = hovering
                mediaKeyManager.keepAlive(for: "mic", isHovering: hovering || isExpanded)
            }
        }
        .onChange(of: actualIsActive) { isActive in
            if !isActive && isExpanded {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    isExpanded = false
                }
            }
        }
        .applyTheme(mediaKeyManager.overlayTheme)
    }
}

struct CameraOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @State private var isHovering: Bool = false
    @State private var isExpanded: Bool = false
    var isPreview: Bool = false
    var previewIsActive: Bool = true
    
    private var actualIsActive: Bool {
        isPreview ? previewIsActive : mediaKeyManager.isCameraActive
    }
    
    private var actionColor: Color {
        actualIsActive ? .blue : .secondary
    }
    
    private var actionTitle: String {
        actualIsActive ? "Camera On" : "Camera Off"
    }
    
    private func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }
    
    var body: some View {
        let trackWidth: CGFloat = 260 - 8
        let expandedHeight: CGFloat = 160
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            progress: 1.0,
            customProgressMask: AnyView(
                TimeoutProgressBar(trackWidth: trackWidth, isHovering: isHovering || isExpanded, initialDuration: MediaKeyManager.notificationDuration, hoverOutDuration: MediaKeyManager.notificationDuration)
                    .id(mediaKeyManager.cameraEventId)
            ),
            barColor: actionColor,
            fillCenter: false,
            isMuted: false,
            listHeight: expandedHeight,
            customWidth: 260,
            supportDragGesture: false,
            onSimpleTap: {
                if !isPreview {
                    mediaKeyManager.keepAlive(for: "camera", isHovering: true)
                }
            },
            isExpandable: actualIsActive,
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
                .padding(.horizontal, 16 + 4 + 3)
            },
            expandedContent: {
                if isExpanded {
                    VStack(spacing: 0) {
                        CameraPreviewView()
                            .scaleEffect(x: -1, y: 1)
                            .frame(height: 128)
                            .cornerRadius(12)
                            .padding(.top, 16)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                } else {
                    EmptyView()
                }
            }
        )
        .frame(width: 260, height: isExpanded ? 56 + expandedHeight : 56, alignment: .top)
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(20)
        .onChange(of: isExpanded) { expanded in
            mediaKeyManager.isCameraExpanded = expanded
            if expanded {
                mediaKeyManager.keepAlive(for: "camera", isHovering: true)
            } else if !isHovering {
                mediaKeyManager.keepAlive(for: "camera", isHovering: false)
            }
        }
        .onHoverExact { hovering in
            if !isPreview {
                isHovering = hovering
                mediaKeyManager.keepAlive(for: "camera", isHovering: hovering || isExpanded)
            }
        }
        .onChange(of: actualIsActive) { isActive in
            if !isActive && isExpanded {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    isExpanded = false
                }
            }
        }
        .applyTheme(mediaKeyManager.overlayTheme)
    }
}

class CameraPreviewController: NSViewController {
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    func setupCamera() {
        captureSession = AVCaptureSession()
        guard let session = captureSession else { return }
        session.sessionPreset = .high
        
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        guard let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.videoGravity = .resizeAspectFill
        
        view.layer = previewLayer
        view.wantsLayer = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let session = self?.captureSession else { return }
            session.startRunning()
        }
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        let session = captureSession
        DispatchQueue.global(qos: .userInitiated).async {
            session?.stopRunning()
            for input in session?.inputs ?? [] {
                session?.removeInput(input)
            }
        }
    }
    
    deinit {
        previewLayer?.removeFromSuperlayer()
        previewLayer?.session = nil
    }
}

struct CameraPreviewView: NSViewControllerRepresentable {
    func makeNSViewController(context: Context) -> CameraPreviewController {
        return CameraPreviewController()
    }

    func updateNSViewController(_ nsViewController: CameraPreviewController, context: Context) {
    }
}
