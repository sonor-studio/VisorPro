import SwiftUI

struct PeripheralOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @State private var isHovering: Bool = false
    @State private var isExpanded: Bool = false
    
    var isPreview: Bool = false
    var previewIsConnected: Bool = false
    var notification: DeviceNotification?
    
    var isConnected: Bool {
        if isPreview { return previewIsConnected }
        if let notif = notification {
            return notif.isConnected
        }
        return mediaKeyManager.peripheralIsConnected
    }
    
    var deviceName: String {
        if isPreview { return "Magic Mouse" }
        if let notif = notification {
            return notif.deviceName
        }
        return mediaKeyManager.peripheralDeviceName
    }
    
    var iconName: String {
        if isPreview { return "magicmouse.fill" }
        if let notif = notification {
            return notif.icon
        }
        return mediaKeyManager.peripheralDeviceIcon
    }
    
    var body: some View {
        let actionColor: Color = isConnected ? .teal : .secondary
        let periPos = UserDefaults.standard.string(forKey: "peripheralOverlayPosition") ?? "bottom"
        
        let hasDetails = isPreview ? true : notification?.details?.isEmpty == false
        let isDrive = isPreview ? false : (notification?.type == "USB Drive" || notification?.type == "USB Device")
        let isExpandable = isConnected && (hasDetails || isDrive)
        
        var calcHeight: CGFloat = 0
        if isExpandable {
            calcHeight += 1 // Divider
            if hasDetails {
                calcHeight += 12 // Spacing before details
                let count = isPreview ? 2 : CGFloat(notification?.details?.count ?? 0)
                calcHeight += (count * 16) + (max(count - 1, 0) * 8) // 16 per row + 8 spacing
            }
            if isDrive {
                calcHeight += 12 // Spacing before buttons
                calcHeight += 46 // buttons: 4 top, 30 content, 12 bottom
            } else if hasDetails {
                calcHeight += 12 // Spacing before clear frame
                calcHeight += 4 // clear frame
            }
        }
        
        let trackWidth: CGFloat = 260 - 8
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            progress: 1.0,
            customProgressMask: AnyView(
                TimeoutProgressBar(trackWidth: trackWidth, isHovering: isHovering || mediaKeyManager.globalHoveredTypes.contains("language"), initialDuration: MediaKeyManager.notificationDuration, hoverOutDuration: MediaKeyManager.notificationDuration)
                    .id(notification?.timestamp ?? Date(timeIntervalSince1970: 0))
            ),
            barColor: actionColor,
            fillCenter: false, // uses strokeBorder
            isMuted: false,
            listHeight: calcHeight,
            customWidth: 260,
            supportDragGesture: false,
            isExpandable: isExpandable,
            expandUpwards: periPos == "bottom",
            baseContent: {
                HStack(alignment: .top, spacing: 0) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isConnected ? .primary : .secondary)
                        .frame(width: 26, height: 24)
                        .padding(.leading, 16)
                        .padding(.top, 4)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isConnected ? "Connected" : "Disconnected")
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
                if isExpandable {
                    VStack(spacing: 12) {
                        let periPos = UserDefaults.standard.string(forKey: "peripheralOverlayPosition") ?? "bottom"
                        if periPos != "bottom" {
                            Divider()
                                .padding(.horizontal, 16)
                                .opacity(0.5)
                        }
                        
                        if let details = notification?.details, !details.isEmpty {
                            VStack(spacing: 8) {
                                ForEach(details.sorted(by: { $0.key > $1.key }), id: \.key) { key, value in
                                    HStack(alignment: .center) {
                                        Text(key)
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundColor(.secondary)
                                            .frame(width: 85, alignment: .leading)
                                        
                                        Spacer(minLength: 4)
                                        
                                        Text(value)
                                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        } else if isPreview {
                            VStack(spacing: 8) {
                                HStack(alignment: .center) {
                                    Text("Manufacturer")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .frame(width: 85, alignment: .leading)
                                    Spacer(minLength: 4)
                                    Text("Apple Inc.")
                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                .padding(.horizontal, 16)
                                HStack(alignment: .center) {
                                    Text("Battery")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .frame(width: 85, alignment: .leading)
                                    Spacer(minLength: 4)
                                    Text("85%")
                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        
                        if isDrive {
                            HStack(spacing: 8) {
                                Button(action: {
                                    if !isPreview {
                                        mediaKeyManager.openDrive(named: deviceName)
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "folder")
                                        Text("Open in Finder")
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.primary.opacity(0.1))
                                    .cornerRadius(28 - 4 - 3)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    if !isPreview {
                                        mediaKeyManager.ejectDrive(named: deviceName)
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "eject")
                                        Text("Eject")
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.primary.opacity(0.1))
                                    .cornerRadius(28 - 4 - 3)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                            .padding(.top, 4)
                        } else if hasDetails {
                            Color.clear.frame(height: 4)
                        }
                        
                        if periPos == "bottom" {
                            Divider()
                                .padding(.horizontal, 16)
                                .opacity(0.5)
                        }
                    }
                } else {
                    EmptyView()
                }
            }
        )
        .frame(width: 260, height: (isExpanded && isExpandable) ? 56 + calcHeight : 56, alignment: .top)

        .padding(20)
        .onChange(of: isExpanded) { _, expanded in
            if !isPreview {
                let keepAliveType = notification != nil ? "peripheral_\(notification!.id)" : "peripheral"
                mediaKeyManager.keepAlive(for: keepAliveType, isHovering: isHovering || expanded)
            }
        }
        .onHoverExact { hovering in
            if !isPreview {
                self.isHovering = hovering
                let keepAliveType = notification != nil ? "peripheral_\(notification!.id)" : "peripheral"
                mediaKeyManager.keepAlive(for: keepAliveType, isHovering: hovering || isExpanded)
            }
        }
        .onChange(of: notification?.isConnected) { _, connected in
            if connected == false {
                isExpanded = false
            }
        }
        .applyTheme(mediaKeyManager.overlayTheme)
    }
}
