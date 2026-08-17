import SwiftUI

struct CapsLockOverlayView: View {
    @State private var isHovering: Bool = false
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    var isPreview: Bool = false
    var previewIsOn: Bool = true
    @State private var localPreviewIsOn: Bool = true
    
    private var actualIsOn: Bool {
        isPreview ? localPreviewIsOn : mediaKeyManager.isCapsLockOn
    }
    
    private var actionColor: Color {
        actualIsOn ? .green : .secondary
    }
    
    private var actionTitle: String {
        actualIsOn ? "Caps Lock ON" : "Caps Lock OFF"
    }
    
    var body: some View {
        let actionTitle = actualIsOn ? "Caps Lock ON" : "Caps Lock OFF"
        let actionColor: Color = actualIsOn ? .green : .secondary
        let trackWidth: CGFloat = 230 - 8
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: .constant(false),
            showProgressBar: true,
            progress: 1.0,
            customProgressMask: AnyView(
                TimeoutProgressBar(trackWidth: trackWidth, isHovering: isHovering || mediaKeyManager.globalHoveredTypes.contains("capsLock"), initialDuration: MediaKeyManager.notificationDuration, hoverOutDuration: MediaKeyManager.notificationDuration)
                    .id(mediaKeyManager.capsLockEventId)
            ),
            barColor: actionColor,
            fillCenter: false, // It was using strokeBorder
            isMuted: false,
            listHeight: 0,
            customWidth: 230,
            supportDragGesture: false,
            onSimpleTap: {
                if isPreview {
                    withAnimation { localPreviewIsOn.toggle() }
                } else {
                    mediaKeyManager.toggleCapsLock()
                }
            },
            baseContent: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: actualIsOn ? "capslock.fill" : "capslock")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Keyboard")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            
                        MarqueeText(text: actionTitle, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                    }
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16 + 4 + 3)
            },
            expandedContent: {
                EmptyView()
            }
        )
        .frame(width: 230, height: 56, alignment: .top)

        .padding(20)
        .onHoverExact { hovering in
            if !isPreview {
                self.isHovering = hovering
                mediaKeyManager.keepAlive(for: "capsLock", isHovering: hovering)
            }
        }
        .onAppear {
            localPreviewIsOn = previewIsOn
        }
        .applyTheme(mediaKeyManager.overlayTheme)
    }
}
