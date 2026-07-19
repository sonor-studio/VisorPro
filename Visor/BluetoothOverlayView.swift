import SwiftUI
import IOBluetooth

struct BluetoothOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @State private var animatedProgress: CGFloat = 1.0
    var isPreview: Bool = false
    var previewIsConnected: Bool = true
    var previewDeviceName: String = "Magic Mouse"
    
    private var actualIsConnected: Bool {
        isPreview ? previewIsConnected : mediaKeyManager.bluetoothIsConnected
    }
    
    private var actualDeviceName: String {
        isPreview ? previewDeviceName : mediaKeyManager.bluetoothDeviceName
    }
    
    private var actionColor: Color {
        actualIsConnected ? .blue : .gray
    }
    
    private var actionTitle: String {
        actualIsConnected ? "Connected" : "Disconnected"
    }
    
    var body: some View {
        let width: CGFloat = 220
        let height: CGFloat = 56
        let trackPadding: CGFloat = 4
        let innerPadding: CGFloat = 4
        
        let trackWidth = width - (trackPadding * 2)
        let trackHeight = height - (trackPadding * 2)
        let innerWidth = trackWidth - (innerPadding * 2)
        let innerHeight = trackHeight - (innerPadding * 2)
        
        ZStack(alignment: .leading) {
            ZStack {
                Capsule()
                    .fill(.regularMaterial)
                
                Capsule()
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: innerPadding)
                    .frame(width: trackWidth, height: trackHeight)
            }
            .frame(width: width, height: height)
            
            Capsule()
                .strokeBorder(actionColor.opacity(0.85), lineWidth: innerPadding)
                .frame(width: trackWidth, height: trackHeight)
                .mask(
                    HStack(spacing: 0) {
                        Rectangle()
                            .frame(width: trackWidth * animatedProgress)
                        Spacer(minLength: 0)
                    }
                )
                .padding(.leading, trackPadding)
            
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.thinMaterial)
                    .frame(width: innerWidth, height: innerHeight)
                
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(actionColor.opacity(0.2))
                            .frame(width: 32, height: 32)
                        
                        let nameLower = actualDeviceName.lowercased()
                        let iconName: String = {
                            if nameLower.contains("airpods") { return "airpods" }
                            if nameLower.contains("mouse") || nameLower.contains("mysz") { return "magicmouse" }
                            if nameLower.contains("keyboard") || nameLower.contains("klawiatur") { return "keyboard" }
                            if nameLower.contains("trackpad") || nameLower.contains("gładzik") { return "magicmouse" }
                            if nameLower.contains("headphone") || nameLower.contains("słuchawk") { return "headphones" }
                            if nameLower.contains("speaker") || nameLower.contains("głośnik") { return "speaker.wave.2" }
                            return "point.3.connected.trianglepath.dotted" // Generic bluetooth-like icon
                        }()
                        
                        Image(systemName: iconName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(actionColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(actionTitle)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                        
                        Text(actualDeviceName.isEmpty ? "Unknown Device" : actualDeviceName)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 12)
                .frame(width: innerWidth, height: innerHeight)
            }
            .padding(.leading, trackPadding + innerPadding)
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(20)
        .environment(\.colorScheme, .dark)
        .onAppear {
            animatedProgress = 1.0
            if !isPreview {
                withAnimation(.linear(duration: 3.5)) {
                    animatedProgress = 0.0
                }
            }
        }
    }
}
