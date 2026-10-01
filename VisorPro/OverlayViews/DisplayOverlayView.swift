import SwiftUI

struct DisplayOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @EnvironmentObject var overlayState: OverlayStateRelay
    @State private var isHovering: Bool = false
    @State private var isExpanded: Bool = false
    @AppStorage("displayAllowExpansion") private var displayAllowExpansion: Bool = true
    
    var isPreview: Bool = false
    var previewIsConnected: Bool = false
    var notification: DeviceNotification?
    
    @State private var previewIsMirrored: Bool = false
    @State private var overridenIsMirrored: Bool? = nil
    
    var isConnected: Bool {
        if isPreview { return previewIsConnected }
        if let notif = notification {
            return notif.isConnected
        }
        return false
    }
    
    var deviceName: String {
        if isPreview { return "LG Ultra HD" }
        if let over = overridenIsMirrored {
            if notification?.isModeChange == true {
                return "Changed to \(over ? "Mirrored" : "Extended")"
            } else {
                return notification?.deviceName ?? "Display"
            }
        }
        if let notif = notification {
            return notif.deviceName
        }
        return "Display"
    }
    
    var isMirrored: Bool {
        if isPreview { return previewIsMirrored }
        if let over = overridenIsMirrored { return over }
        if let notif = notification, let details = notif.details, let val = details["isMirrored"] {
            return val == "true"
        }
        return false
    }
    
    var iconName: String {
        if isPreview { return "display.2" }
        if let over = overridenIsMirrored { return over ? "rectangle.on.rectangle" : "rectangle.split.2x1" }
        if let notif = notification {
            return notif.icon
        }
        return "display"
    }
    
    var typeText: String {
        if isPreview { return "Mode: Extended" }
        if let over = overridenIsMirrored {
            if notification?.isModeChange == true {
                return notification?.type ?? "Display"
            } else {
                return "Mode: \(over ? "Mirrored" : "Extended")"
            }
        }
        if let notif = notification {
            return notif.type
        }
        return ""
    }
    
    var body: some View {
        let actionColor: Color = isConnected ? Color(red: 0.0, green: 0.8, blue: 0.7) : .offStateGray
        let pos = MediaKeyManager.shared.getOverlayPosition(for: "displayOverlayPosition")
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            hasTimeoutProgress: true,
            timeoutEventId: notification?.timestamp ?? Date(timeIntervalSince1970: 0),
            barColor: !isConnected ? .offStateGray : (notification?.isModeChange == true ? OverlayColorManager.shared.getOverlayColor(for: "colorOnDisplayModeChange", defaultColor: actionColor) : OverlayColorManager.shared.getOverlayColor(for: "colorOnDisplayConnect", defaultColor: actionColor)),
            fillCenter: false,
            isMuted: false,
            customWidth: 260,
            supportDragGesture: false,
            onRightTap: isConnected ? {
                manualToggle()
            } : nil,
            isExpandable: displayAllowExpansion,
            expandUpwards: pos.hasPrefix("bottom"),
            keepAliveId: "display_\(notification?.id ?? deviceName)",
            baseContent: {
                HStack(alignment: .center, spacing: 0) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isConnected ? .primary : .offStateGray)
                        .frame(width: 26, height: 24)
                        .padding(.leading, 23)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isConnected ? typeText : "Disconnected")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.offStateGray)
                        
                        MarqueeText(text: deviceName, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 14)
                    
                    Spacer(minLength: 8)
                    
                    if isConnected {
                        ZStack {
                            Circle()
                                .fill(Color.primary.opacity(0.1))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: notification?.isModeChange == true ? "arrow.uturn.backward" : (isMirrored ? "rectangle.split.2x1" : "rectangle.on.rectangle"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .padding(.trailing, 12)
                    } else {
                        Color.clear.frame(width: 1, height: 1)
                            .padding(.trailing, 22)
                    }
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
                        .foregroundColor(.offStateGray)
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
                                    .foregroundColor(isMirrored ? .offStateGray : .primary)
                                    .cornerRadius(6)
                            }
                            .contentShape(Rectangle())
                            .buttonStyle(.plain)
                            .pointingHandCursor()
                            
                            Button(action: {
                                if !isMirrored { manualToggle() }
                            }) {
                                Text("Mirror")
                                    .font(.system(size: 11, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 5)
                                    .background(!isMirrored ? Color.clear : Color.primary.opacity(0.15))
                                    .foregroundColor(!isMirrored ? .offStateGray : .primary)
                                    .cornerRadius(6)
                            }
                            .contentShape(Rectangle())
                            .buttonStyle(.plain)
                            .pointingHandCursor()
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
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded = false
                        }
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
                    .pointingHandCursor()
                    .padding(.horizontal, 16)
                }
                .padding(.top, 4)
            }
        )
        .onChange(of: notification?.timestamp) { _, _ in
            overridenIsMirrored = nil
        }
        .onChange(of: notification?.id) { _, _ in
            if !isConnected {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded = false
                }
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
        
        guard !overlayState.isDisplayTransitioning else { return }
        
        let newMirrored = !isMirrored
        
        withAnimation {
            overridenIsMirrored = newMirrored
        }
        
        overlayState.isDisplayTransitioning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            overlayState.isDisplayTransitioning = false
        }
        
        if newMirrored {
            overlayState.forceSingleScreenForDisplayTransition = true
            VisorProWindowManager.shared.updateWindows() // Hide secondary window immediately!
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                overlayState.forceSingleScreenForDisplayTransition = false
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
            type: newMirrored ? "Mode: Mirrored" : "Mode: Extended",
            typeIcon: newMirrored ? "rectangle.on.rectangle" : "rectangle.split.2x1",
            isConnected: true,
            isModeChange: true,
            details: details
        )
    }
}
