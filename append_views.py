code = """
struct ThemeOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @Environment(\\.colorScheme) var colorScheme
    
    var isPreview: Bool = false
    var previewIsDark: Bool = false
    
    var body: some View {
        let isDark = isPreview ? previewIsDark : (colorScheme == .dark)
        let iconName = isDark ? "moon.fill" : "sun.max.fill"
        let titleText = isDark ? "Ciemny" : "Jasny"
        let iconColor: Color = isDark ? .indigo : .yellow
        
        let width: CGFloat = 200
        let height: CGFloat = 56
        let trackPadding: CGFloat = 4
        let innerPadding: CGFloat = 4
        
        let trackWidth = width - (trackPadding * 2)
        let trackHeight = height - (trackPadding * 2)
        let innerWidth = trackWidth - (innerPadding * 2)
        let innerHeight = trackHeight - (innerPadding * 2)
        
        ZStack(alignment: .leading) {
            // WARSTWA 1: Baza
            ZStack {
                Capsule()
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
                
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: innerPadding)
                    .frame(width: trackWidth, height: trackHeight)
            }
            .frame(width: width, height: height)
            
            // WARSTWA 2: Kolorowa ramka
            Capsule()
                .strokeBorder(iconColor.opacity(0.85), lineWidth: innerPadding)
                .frame(width: trackWidth, height: trackHeight)
                .padding(.leading, trackPadding)
                .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
            
            // WARSTWA 3: Górna warstwa
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.thinMaterial)
                    .frame(width: innerWidth, height: innerHeight)
                    .overlay(
                        Capsule().strokeBorder(Color.innerBorder.opacity(0.2), lineWidth: 1)
                    )
                
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(iconColor)
                        .frame(width: 26, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Motyw")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                        
                        MarqueeText(text: titleText, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                    }
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16)
                .frame(width: innerWidth, height: innerHeight)
            }
            .padding(.leading, trackPadding + innerPadding)
        }
        .frame(width: width, height: height)
        .contentShape(Capsule())
        .onHover { isHovering in
            mediaKeyManager.keepAlive(for: "theme", isHovering: isHovering)
        }
        .padding(20)
        .environment(\\.colorScheme, .dark)
    }
}

struct PeripheralOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    
    var isPreview: Bool = false
    var previewIsConnected: Bool = false
    
    var isConnected: Bool {
        if isPreview { return previewIsConnected }
        if let notif = mediaKeyManager.activePeripheralNotifications.last {
            return notif.isConnected
        }
        return mediaKeyManager.peripheralIsConnected
    }
    
    var deviceName: String {
        if isPreview { return "Magic Mouse" }
        if let notif = mediaKeyManager.activePeripheralNotifications.last {
            return notif.deviceName
        }
        return mediaKeyManager.peripheralDeviceName
    }
    
    var iconName: String {
        if isPreview { return "magicmouse.fill" }
        if let notif = mediaKeyManager.activePeripheralNotifications.last {
            return notif.icon
        }
        return mediaKeyManager.peripheralDeviceIcon
    }
    
    var body: some View {
        let actionColor: Color = isConnected ? .green : .red
        
        let width: CGFloat = 260
        let height: CGFloat = 56
        let trackPadding: CGFloat = 4
        let innerPadding: CGFloat = 4
        
        let trackWidth = width - (trackPadding * 2)
        let trackHeight = height - (trackPadding * 2)
        let innerWidth = trackWidth - (innerPadding * 2)
        let innerHeight = trackHeight - (innerPadding * 2)
        
        ZStack(alignment: .leading) {
            // WARSTWA 1: Baza
            ZStack {
                Capsule()
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
                
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: innerPadding)
                    .frame(width: trackWidth, height: trackHeight)
            }
            .frame(width: width, height: height)
            
            // WARSTWA 2: Kolorowa ramka
            Capsule()
                .strokeBorder(actionColor.opacity(0.85), lineWidth: innerPadding)
                .frame(width: trackWidth, height: trackHeight)
                .padding(.leading, trackPadding)
                .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
            
            // WARSTWA 3: Górna warstwa
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.thinMaterial)
                    .frame(width: innerWidth, height: innerHeight)
                    .overlay(
                        Capsule().strokeBorder(Color.innerBorder.opacity(0.2), lineWidth: 1)
                    )
                
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(actionColor)
                        .frame(width: 26, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isConnected ? "Połączono" : "Rozłączono")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                        
                        MarqueeText(text: deviceName, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                    }
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16)
                .frame(width: innerWidth, height: innerHeight)
            }
            .padding(.leading, trackPadding + innerPadding)
        }
        .frame(width: width, height: height)
        .contentShape(Capsule())
        .onHover { isHovering in
            mediaKeyManager.keepAlive(for: "peripheral", isHovering: isHovering)
        }
        .padding(20)
        .environment(\\.colorScheme, .dark)
    }
}
"""

with open('/Users/macbook/Desktop/Dev/Visor/Visor/ContentView.swift', 'a') as f:
    f.write("\n" + code + "\n")
