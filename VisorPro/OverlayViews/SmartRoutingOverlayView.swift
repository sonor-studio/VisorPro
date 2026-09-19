import SwiftUI

struct SmartRoutingOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @EnvironmentObject var overlayState: OverlayStateRelay
    @State private var isExpanded: Bool = false
    
    var isPreview: Bool = false
    
    private var displayTitle: String {
        if isPreview { return "AirPods Pro" }
        let parts = overlayState.smartRoutingText.components(separatedBy: "|")
        return parts.first ?? "AirPods"
    }
    
    private var displayMessage: String {
        if isPreview { return "Moved to iPhone" }
        let parts = overlayState.smartRoutingText.components(separatedBy: "|")
        return parts.count > 1 ? parts[1] : "Audio Transferred"
    }
    
    private var deviceIcon: String {
        return mediaKeyManager.peripheralIcons[displayTitle] ?? MediaKeyManager.fallbackIcon(for: displayTitle)
    }
    
    private var overlayColor: Color {
        let baseName = displayTitle
        var settings = mediaKeyManager.accessorySettings[baseName]
        if settings == nil {
            settings = mediaKeyManager.accessorySettings.first(where: { $0.key.lowercased().contains("airpods") })?.value
        }
        
        let finalSettings = settings ?? AccessoryDeviceSettings()
        if finalSettings.colorOnSmartRouting != "Default" {
            return OverlayColorManager.shared.parseColor(finalSettings.colorOnSmartRouting)
        }
        return OverlayColorManager.shared.getOverlayColor(for: "colorOnBluetoothConnect", defaultColor: .blue)
    }
    
    var body: some View {
        let batPos = MediaKeyManager.shared.getOverlayPosition(for: "bluetoothOverlayPosition")
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            progress: 1.0,
            hasTimeoutProgress: true,
            timeoutEventId: overlayState.smartRoutingEventId,
            barColor: overlayColor,
            fillCenter: false,
            customWidth: 260,
            customHeight: 56,
            supportDragGesture: false,
            onRightTap: {
                if !isPreview {
                    mediaKeyManager.returnAudioToMac()
                    withAnimation(.easeInOut(duration: 0.25)) {
                        overlayState.showSmartRoutingIndicator = false
                    }
                    mediaKeyManager.notifyOverlayStateChanged()
                }
            },
            isExpandable: false,
            expandUpwards: batPos.hasPrefix("bottom"),
            keepAliveId: "smartRouting",
            baseContent: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: deviceIcon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayTitle)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        MarqueeText(text: displayMessage, font: .system(size: 13, weight: .semibold, design: .rounded), foregroundColor: .primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer(minLength: 8)
                    
                    if overlayState.isSmartRoutingUndoAvailable {
                        ZStack {
                            Circle()
                                .fill(Color.primary.opacity(0.1))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.leading, 23)
                .padding(.trailing, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            },
            expandedContent: { EmptyView() }
        )
        .id(overlayState.smartRoutingEventId)
    }
}
