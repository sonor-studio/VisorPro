import SwiftUI

struct MicOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @State private var isHovering: Bool = false
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
    
    var body: some View {
        let trackWidth: CGFloat = 220 - 8 // width - 2*trackPadding
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: .constant(false),
            showProgressBar: true,
            progress: 1.0,
            customProgressMask: AnyView(
                TimeoutProgressBar(trackWidth: trackWidth, isHovering: isHovering, initialDuration: MediaKeyManager.notificationDuration, hoverOutDuration: MediaKeyManager.notificationDuration)
                    .id(mediaKeyManager.micEventId)
            ),
            barColor: actionColor,
            fillCenter: false,
            isMuted: false,
            listHeight: 0,
            customWidth: 220,
            supportDragGesture: false,
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
                        
                        MarqueeText(text: isPreview ? "System Microphone" : (mediaKeyManager.activeMicName.isEmpty ? "Microphone" : mediaKeyManager.activeMicName), font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                    }
                    
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16 + 4 + 3)
            },
            expandedContent: { EmptyView() }
        )
        .frame(width: 220, height: 56, alignment: .top)
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(20)
        .onHover { hovering in
            if !isPreview {
                isHovering = hovering
                mediaKeyManager.keepAlive(for: "mic", isHovering: hovering)
            }
        }
        .applyTheme(mediaKeyManager.overlayTheme)
    }
}

struct CameraOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @State private var isHovering: Bool = false
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
    
    var body: some View {
        let trackWidth: CGFloat = 220 - 8
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: .constant(false),
            showProgressBar: true,
            progress: 1.0,
            customProgressMask: AnyView(
                TimeoutProgressBar(trackWidth: trackWidth, isHovering: isHovering, initialDuration: MediaKeyManager.notificationDuration, hoverOutDuration: MediaKeyManager.notificationDuration)
                    .id(mediaKeyManager.cameraEventId)
            ),
            barColor: actionColor,
            fillCenter: false,
            isMuted: false,
            listHeight: 0,
            customWidth: 220,
            supportDragGesture: false,
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
            expandedContent: { EmptyView() }
        )
        .frame(width: 220, height: 56, alignment: .top)
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(20)
        .onHover { hovering in
            if !isPreview {
                isHovering = hovering
                mediaKeyManager.keepAlive(for: "camera", isHovering: hovering)
            }
        }
        .applyTheme(mediaKeyManager.overlayTheme)
    }
}
