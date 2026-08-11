import SwiftUI
import IOBluetooth

struct BluetoothOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @State private var isHovering = false
    @State private var refreshTimer: Timer?
    @State private var isExpanded: Bool = false
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
        let actionColor: Color = actualIsConnected ? .blue : .secondary
        let trackWidth: CGFloat = 260 - 8 // width - 2*trackPadding
        
        let deviceId = isPreview ? "00:11:22:33:44:55" : (notification?.id ?? "")
        let hasDetails = isPreview || mediaKeyManager.bluetoothDetails[deviceId] != nil
        let systemName = mediaKeyManager.bluetoothDetails[deviceId]?["SystemName"] ?? actualDeviceName
        let deviceBatteries = mediaKeyManager.accessoryBatteryLevels.filter { $0.key.hasPrefix(systemName) }
        
        var rowsCount = 0
        if actualIsConnected && hasDetails {
            rowsCount = (isPreview ? 5 : 4 + deviceBatteries.count)
        } else if !actualIsConnected && hasDetails {
            rowsCount = 1
        }
        let listHeight: CGFloat = actualIsConnected ? (hasDetails ? CGFloat(rowsCount * 22 + 80) : 100) : 70
        
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
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            progress: 1.0,
            customProgressMask: AnyView(
                TimeoutProgressBar(trackWidth: trackWidth, isHovering: isHovering || isExpanded, initialDuration: MediaKeyManager.notificationDuration, hoverOutDuration: MediaKeyManager.notificationDuration)
                    .id(notification?.timestamp ?? Date(timeIntervalSince1970: 0))
            ),
            barColor: actionColor,
            fillCenter: false,
            isMuted: false,
            listHeight: listHeight,
            customWidth: 260,
            supportDragGesture: false,
            onSimpleTap: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    if !isExpanded && actualIsConnected {
                        mediaKeyManager.fetchBluetoothDetails()
                    }
                }
                if !isPreview {
                    let keepAliveType = notification != nil ? "bluetooth_\(notification!.id)" : "bluetooth"
                    mediaKeyManager.keepAlive(for: keepAliveType, isHovering: true)
                }
            },
            baseContent: {
                HStack(alignment: .top, spacing: 0) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(actualIsConnected ? .primary : .secondary)
                        .frame(width: 26, height: 24)
                        .padding(.leading, 16)
                        .padding(.top, 4)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(actionTitle)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.leading, 14)
                            .padding(.trailing, 16)
                        
                        MarqueeText(text: actualDeviceName.isEmpty ? "Unknown Device" : actualDeviceName, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                            .padding(.leading, 14)
                            .padding(.trailing, 16)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 5)
            },
            expandedContent: {
                VStack(spacing: 12) {
                    Divider()
                        .padding(.horizontal, 16)
                        .opacity(0.5)
                    
                    if actualIsConnected && !hasDetails {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(height: 50)
                    } else {
                        VStack(spacing: 8) {
                            if let details = isPreview ? ["MAC": "00:11:22:33:44:55", "Typ": "Audio", "Firmware": "1.0.0", "RSSI": "-45 dBm", "SystemName": "AirPods Pro"] : mediaKeyManager.bluetoothDetails[deviceId] {
                                if let mac = details["MAC"] {
                                    StatRow(icon: "network", label: "MAC Address", value: mac, allowShrink: true)
                                }
                                if let type = details["Typ"] {
                                    StatRow(icon: "tag", label: "Type", value: type)
                                }
                                if let fw = details["Firmware"] {
                                    StatRow(icon: "cpu", label: "Firmware", value: fw)
                                }
                                if actualIsConnected, let rssi = details["RSSI"] {
                                    StatRow(icon: "antenna.radiowaves.left.and.right", label: "Signal", value: rssi)
                                }
                                
                                if isPreview {
                                    StatRow(icon: "battery.100", label: "Battery", value: "85%")
                                } else {
                                    ForEach(deviceBatteries.sorted(by: { $0.key < $1.key }), id: \.key) { key, battery in
                                        let charging = mediaKeyManager.accessoryBatteryCharging[key] ?? false
                                        let suffix = key.replacingOccurrences(of: systemName, with: "").trimmingCharacters(in: .whitespaces)
                                        let label = suffix.isEmpty ? "Battery" : "Battery \(suffix)"
                                        StatRow(icon: charging ? "battery.100.bolt" : "battery.100", label: label, value: "\(battery)%")
                                    }
                                }
                            }
                            
                            if !actualIsConnected {
                                StatRow(icon: "wifi.slash", label: "Status", value: "Disconnected")
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    HStack(spacing: 8) {
                        Button(action: {
                            mediaKeyManager.openBluetoothSettings()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                isExpanded = false
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "gear")
                                Text("Bluetooth Settings")
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
                }
            }
        )
        .frame(width: 260, height: isExpanded ? 56 + listHeight : 56, alignment: .top)
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(20)
        .onHover { hovering in
            if !isPreview {
                isHovering = hovering
                let keepAliveType = notification != nil ? "bluetooth_\(notification!.id)" : "bluetooth"
                mediaKeyManager.keepAlive(for: keepAliveType, isHovering: hovering || isExpanded)
            }
        }
        .onChange(of: isExpanded) { expanded in
            if expanded && actualIsConnected {
                refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                    mediaKeyManager.fetchBluetoothDetails()
                }
            } else {
                refreshTimer?.invalidate()
                refreshTimer = nil
            }
        }
        .applyTheme(mediaKeyManager.overlayTheme)
    }
}
