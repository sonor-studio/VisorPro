import SwiftUI

struct DisplayOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @State private var isHovering: Bool = false
    @State private var isExpanded: Bool = false
    @AppStorage("displayAllowExpansion") private var displayAllowExpansion: Bool = true
    
    var isPreview: Bool = false
    var previewIsConnected: Bool = false
    var notification: DeviceNotification?
    
    @State private var previewIsMirrored: Bool = false
    
    var isConnected: Bool {
        if isPreview { return previewIsConnected }
        if let notif = notification {
            return notif.isConnected
        }
        return false
    }
    
    var deviceName: String {
        if isPreview { return "LG Ultra HD" }
        if let notif = notification {
            return notif.deviceName
        }
        return "Display"
    }
    
    var isMirrored: Bool {
        if isPreview { return previewIsMirrored }
        if let notif = notification, let details = notif.details, let val = details["isMirrored"] {
            return val == "true"
        }
        return false
    }
    
    var iconName: String {
        if isPreview { return "display.2" }
        if let notif = notification {
            return notif.icon
        }
        return "display"
    }
    
    var typeText: String {
        if isPreview { return "Mode: Extended" }
        if let notif = notification {
            return notif.type
        }
        return ""
    }
    
    var body: some View {
        let actionColor: Color = isConnected ? Color(red: 0.0, green: 0.8, blue: 0.7) : .secondary
        let pos = UserDefaults.standard.string(forKey: "displayOverlayPosition") ?? "bottom"
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            hasTimeoutProgress: true,
            timeoutEventId: notification?.timestamp ?? Date(timeIntervalSince1970: 0),
            barColor: actionColor,
            fillCenter: false,
            isMuted: false,
            customWidth: 260,
            supportDragGesture: false,
            isExpandable: displayAllowExpansion,
            expandUpwards: pos == "bottom",
            keepAliveId: "display_\(notification?.id ?? deviceName)",
            baseContent: {
                HStack(alignment: .top, spacing: 0) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isConnected ? .primary : .secondary)
                        .frame(width: 26, height: 24)
                        .padding(.leading, 16)
                        .padding(.top, 4)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isConnected ? typeText : "Disconnected")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.leading, 14)
                            .padding(.trailing, 16)
                        
                        MarqueeText(text: deviceName, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                            .padding(.leading, 14)
                            .padding(.trailing, 16)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 5)
            },
            expandedContent: {
                VStack(spacing: 8) {
                    if let details = notification?.details, let res = details["resolution"], let rr = details["refreshRate"] {
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "rectangle.dashed")
                                    .font(.system(size: 10))
                                Text(res)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(6)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 10))
                                Text(rr)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(6)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    if isConnected {
                        HStack(spacing: 0) {
                            Button(action: {
                                if isMirrored { manualToggle() }
                            }) {
                                Text("Extend")
                                    .font(.system(size: 11, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 5)
                                    .background(isMirrored ? Color.clear : Color.primary.opacity(0.15))
                                    .foregroundColor(isMirrored ? .secondary : .primary)
                                    .cornerRadius(6)
                            }
                            .contentShape(Rectangle())
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                if !isMirrored { manualToggle() }
                            }) {
                                Text("Mirror")
                                    .font(.system(size: 11, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 5)
                                    .background(!isMirrored ? Color.clear : Color.primary.opacity(0.15))
                                    .foregroundColor(!isMirrored ? .secondary : .primary)
                                    .cornerRadius(6)
                            }
                            .contentShape(Rectangle())
                            .buttonStyle(.plain)
                        }
                        .padding(2)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(8)
                        .padding(.horizontal, 16)
                    }
                    
                    Button(action: {
                        if isPreview { return }
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.displays") {
                            NSWorkspace.shared.open(url)
                        }
                        isExpanded = false
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "gearshape.fill")
                            Text("Settings")
                        }
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 4)
            }
        )
        .onChange(of: notification?.id) { _, _ in
            if !isConnected {
                isExpanded = false
            }
        }
    }
    
    private func manualToggle() {
        if isPreview {
            withAnimation {
                previewIsMirrored.toggle()
            }
            return
        }
        
        let newMirrored = !isMirrored
        
        mediaKeyManager.isDisplayTransitioning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            mediaKeyManager.isDisplayTransitioning = false
        }
        
        if newMirrored {
            mediaKeyManager.forceSingleScreenForDisplayTransition = true
            VisorProWindowManager.shared.updateWindows() // Hide secondary window immediately!
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                mediaKeyManager.forceSingleScreenForDisplayTransition = false
            }
        }
        
        // Delay the hardware toggle so the WindowServer has time to process the window destruction
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            DisplayController.toggleMirrorMode()
        }
        
        var details = notification?.details ?? [:]
        details["isMirrored"] = String(newMirrored)
        
        mediaKeyManager.triggerDisplayIndicator(
            id: notification?.id ?? deviceName,
            deviceName: "Changed to \(newMirrored ? "Mirrored" : "Extended")",
            type: notification?.id ?? deviceName,
            typeIcon: newMirrored ? "display.2" : "macwindow.badge.plus",
            isConnected: true,
            isModeChange: true,
            details: details
        )
    }
}
