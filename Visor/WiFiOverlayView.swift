import SwiftUI

struct WiFiOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @State private var isHovering: Bool = false
    var isPreview: Bool = false
    var previewIsConnected: Bool = true
    var previewSSID: String = "My Wi-Fi"
    
    private var actualIsConnected: Bool {
        isPreview ? previewIsConnected : mediaKeyManager.wiFiIsConnected
    }
    
    private var actualSSID: String {
        isPreview ? previewSSID : mediaKeyManager.wiFiSSID
    }
    
    private var actualIsHotspot: Bool {
        isPreview ? false : mediaKeyManager.wiFiIsHotspot
    }
    
    private var actionColor: Color {
        actualIsConnected ? .cyan : .secondary
    }
    
    private var actionTitle: String {
        if actualIsConnected {
            return actualIsHotspot ? "Hotspot Connected" : "Wi-Fi Connected"
        } else {
            return actualIsHotspot ? "Hotspot Disconnected" : "Wi-Fi Disconnected"
        }
    }
    
    var body: some View {
        let width: CGFloat = 220
        let height: CGFloat = 56
        let trackPadding: CGFloat = 4
        let innerPadding: CGFloat = 3
        
        let trackWidth = width - (trackPadding * 2)
        let trackHeight = height - (trackPadding * 2)
        let innerWidth = trackWidth - (innerPadding * 2)
        let innerHeight = trackHeight - (innerPadding * 2)
        
        ZStack(alignment: .leading) {
            ZStack {
                ActiveVisualEffectView()
                    .clipShape(Capsule())
                
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: innerPadding)
                    .frame(width: trackWidth, height: trackHeight)
            }
            .frame(width: width, height: height)
            
            Capsule()
                .strokeBorder(actionColor.opacity(0.85), lineWidth: innerPadding)
                .frame(width: trackWidth, height: trackHeight)
                .mask(
                    HStack(spacing: 0) {
                        TimeoutProgressBar(trackWidth: trackWidth, isHovering: isHovering, initialDuration: MediaKeyManager.notificationDuration, hoverOutDuration: MediaKeyManager.notificationDuration)
                            .id(mediaKeyManager.wiFiEventId)
                        Spacer(minLength: 0)
                    }
                )
                .padding(.leading, trackPadding)
            
            HStack(alignment: .center, spacing: 14) {
                    let iconName = actualIsConnected ? (actualIsHotspot ? "personalhotspot" : "wifi") : "wifi.slash"
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(actualIsConnected ? .primary : .secondary)
                        .frame(width: 26, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(actionTitle)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        MarqueeText(text: actualSSID.isEmpty ? "No Network" : actualSSID, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                    }
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 12)
                .frame(width: innerWidth, height: innerHeight)
                .background(.regularMaterial, in: Capsule())
            .padding(.leading, trackPadding + innerPadding)
        }
        .frame(width: width, height: height)
        .contentShape(Capsule())
        .onHover { hovering in
            if !isPreview {
                isHovering = hovering
                mediaKeyManager.keepAlive(for: "wifi", isHovering: hovering)
            }
        }
        
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(20)
        .applyTheme(mediaKeyManager.overlayTheme)
        .onChange(of: isHovering) { hovering in
            if !isPreview {
                if hovering {
                } else {
                }
            }
        }
    }
}
