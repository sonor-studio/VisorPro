import SwiftUI
import IOBluetooth

struct BluetoothOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @State private var isHovering: Bool = false
    var isPreview: Bool = false
    var previewIsConnected: Bool = true
    var previewDeviceName: String = "Magic Mouse"
    var notification: DeviceNotification?
    
    private var actualIsConnected: Bool {
        if isPreview { return previewIsConnected }
        if let notif = notification { return notif.isConnected }
        return mediaKeyManager.bluetoothIsConnected // Fallback if needed
    }
    
    private var actualDeviceName: String {
        if isPreview { return previewDeviceName }
        if let notif = notification { return notif.deviceName }
        return mediaKeyManager.bluetoothDeviceName
    }
    
    private var actionColor: Color {
        actualIsConnected ? .blue : .secondary
    }
    
    private var actionTitle: String {
        actualIsConnected ? "Bluetooth Connected" : "Bluetooth Disconnected"
    }
    
    var body: some View {
        let width: CGFloat = 220
        let height: CGFloat = 56
        let trackPadding: CGFloat = 4
        let innerPadding: CGFloat = 3
        
        let trackWidth = width - (trackPadding * 2)
        let trackHeight = height - (trackPadding * 2)
        let innerWidth = trackWidth - (innerPadding * 2)
        let innerHeight = trackHeight - (trackPadding * 2)
        
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
                            .id(notification?.timestamp ?? Date())
                        Spacer(minLength: 0)
                    }
                )
                .padding(.leading, trackPadding)
            
            HStack(alignment: .center, spacing: 14) {
                    let nameLower = actualDeviceName.lowercased()
                    let iconName: String = {
                        if nameLower.contains("airpods") { return "airpods" }
                        if nameLower.contains("mouse") { return "magicmouse" }
                        if nameLower.contains("keyboard") { return "keyboard" }
                        if nameLower.contains("trackpad") { return "magicmouse" }
                        if nameLower.contains("headphone") { return "headphones" }
                        if nameLower.contains("speaker") { return "speaker.wave.2" }
                        return "point.3.connected.trianglepath.dotted"
                    }()
                    
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(actualIsConnected ? .primary : .secondary)
                        .frame(width: 26, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(actionTitle)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        MarqueeText(text: actualDeviceName.isEmpty ? "Unknown Device" : actualDeviceName, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                    }
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 12)
                .frame(width: innerWidth, height: innerHeight)
                .glassEffect(.thinMaterial, in: Capsule())
            .padding(.leading, trackPadding + innerPadding)
        }
        .frame(width: width, height: height)
        .contentShape(Capsule())
        .onHover { hovering in
            if !isPreview {
                isHovering = hovering
                let keepAliveType = notification != nil ? "bluetooth_\(notification!.id)" : "bluetooth"
                mediaKeyManager.keepAlive(for: keepAliveType, isHovering: hovering)
            }
        }
        
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(20)
        .applyTheme(mediaKeyManager.overlayTheme)
    }
}
