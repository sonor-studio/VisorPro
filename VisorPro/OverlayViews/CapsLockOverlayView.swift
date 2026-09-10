import SwiftUI

struct CapsLockOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @EnvironmentObject var overlayState: OverlayStateRelay
    @AppStorage("capsLockAllowInteractivity") private var capsLockAllowInteractivity: Bool = true
    var isPreview: Bool = false
    var previewIsOn: Bool = true
    @State private var localPreviewIsOn: Bool = true
    
    private var actualIsOn: Bool {
        isPreview ? localPreviewIsOn : overlayState.isCapsLockOn
    }
    
    private var actionColor: Color {
        actualIsOn ? .mint : .offStateGray
    }
    
    private var actionTitle: String {
        actualIsOn ? "Caps Lock ON" : "Caps Lock OFF"
    }
    
    var body: some View {
        let actionTitle = actualIsOn ? "Caps Lock ON" : "Caps Lock OFF"
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: .constant(false),
            showProgressBar: true,
            hasTimeoutProgress: true,
            timeoutEventId: overlayState.capsLockEventId,
            barColor: actualIsOn ? OverlayColorManager.shared.getOverlayColor(for: "colorOnCapsLock", defaultColor: .green) : .offStateGray,
            fillCenter: false,
            isMuted: false,
            customWidth: 230,
            supportDragGesture: false,
            onSimpleTap: {
                if capsLockAllowInteractivity {
                    if isPreview {
                        withAnimation { localPreviewIsOn.toggle() }
                    } else {
                        mediaKeyManager.toggleCapsLock()
                    }
                }
            },
            isExpandable: false,
            keepAliveId: "capsLock",
            baseContent: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: actualIsOn ? "capslock.fill" : "capslock")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Keyboard")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.offStateGray)
                            
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
        .id(overlayState.capsLockEventId)
        .frame(width: 230, height: 56, alignment: .top)
        .onAppear {
            localPreviewIsOn = previewIsOn
        }
    }
}
