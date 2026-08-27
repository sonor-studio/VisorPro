import SwiftUI
import IOBluetooth

struct BluetoothOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("bluetoothAllowExpansion") private var bluetoothAllowExpansion: Bool = true
    @State private var isHovering = false
    @State private var refreshTimer: Timer?
    @State private var isExpanded: Bool = false
    @State private var showDetails: Bool = false
    var isPreview: Bool = false
    var previewIsConnected: Bool = true
    var previewDeviceName: String = "AirPods Pro"
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
        actualIsConnected ? .indigo : .secondary
    }
    
    private var actionTitle: String {
        actualIsConnected ? "Bluetooth Connected" : "Bluetooth Disconnected"
    }
    
    private func iconFor(suffix: String, deviceName: String) -> String {
        let lowerSuffix = suffix.lowercased()
        let lowerName = deviceName.lowercased()
        
        if lowerSuffix.contains("left") || lowerSuffix.contains("lewa") {
            return "airpodpro.left"
        } else if lowerSuffix.contains("right") || lowerSuffix.contains("prawa") {
            return "airpodpro.right"
        } else if lowerSuffix.contains("case") || lowerSuffix.contains("etui") {
            return "airpodspro.chargingcase.wireless.fill"
        } else if lowerName.contains("mouse") || lowerName.contains("mysz") {
            return "magicmouse.fill"
        } else if lowerName.contains("keyboard") || lowerName.contains("klawiatura") {
            return "keyboard.fill"
        } else if lowerName.contains("trackpad") {
            return "magicmouse.fill" 
        } else {
            return "headphones"
        }
    }
    
    private func sortWeight(for key: String) -> Int {
        let lower = key.lowercased()
        if lower.contains("left") || lower.contains("lewa") { return 1 }
        if lower.contains("case") || lower.contains("etui") { return 2 }
        if lower.contains("right") || lower.contains("prawa") { return 3 }
        return 4
    }
    
    var body: some View {
        
        let deviceId = isPreview ? "00:11:22:33:44:55" : (notification?.id ?? "")
        let hasDetails = isPreview || mediaKeyManager.bluetoothDetails[deviceId] != nil
        let systemName = mediaKeyManager.bluetoothDetails[deviceId]?["SystemName"] ?? actualDeviceName
        let deviceBatteries = mediaKeyManager.accessoryBatteryLevels.filter { $0.key.hasPrefix(systemName) }
        let effectiveDeviceBatteries: [String: Int] = isPreview ? [
            "\(systemName) (Left)": 85,
            "\(systemName) (Right)": 100,
            "\(systemName) (Case)": 20
        ] : deviceBatteries.reduce(into: [:]) { $0[$1.key] = $1.value }
        
        var rowsCount = 0
        if isPreview {
            rowsCount = 4
        } else if actualIsConnected, let details = mediaKeyManager.bluetoothDetails[deviceId] {
            if details["MAC"] != nil { rowsCount += 1 }
            if details["Typ"] != nil { rowsCount += 1 }
            if details["Firmware"] != nil { rowsCount += 1 }
            if details["RSSI"] != nil { rowsCount += 1 }
        }
        
        let nameLower = actualDeviceName.lowercased()
        
        let iconName: String = {
            if let customIcon = mediaKeyManager.peripheralIcons[systemName], customIcon != "bolt.batteryblock.fill" {
                if customIcon == "airpodpro.left" || customIcon == "airpodpro.right" { return "airpods" }
                if customIcon == "airpodspro.chargingcase.wireless.fill" { return "airpods" }
                return customIcon
            }
            if let customIcon = mediaKeyManager.peripheralIcons[actualDeviceName], customIcon != "bolt.batteryblock.fill" {
                if customIcon == "airpodpro.left" || customIcon == "airpodpro.right" { return "airpods" }
                if customIcon == "airpodspro.chargingcase.wireless.fill" { return "airpods" }
                return customIcon
            }
            if nameLower.contains("airpods") { return "airpods" }
            if nameLower.contains("mouse") { return "magicmouse" }
            if nameLower.contains("keyboard") { return "keyboard" }
            if nameLower.contains("trackpad") { return "magicmouse" }
            if nameLower.contains("headphone") { return "headphones" }
            if nameLower.contains("speaker") { return "speaker.wave.2" }
            return "point.3.connected.trianglepath.dotted"
        }()
        
        let btPos = MediaKeyManager.shared.getOverlayPosition(for: "bluetoothOverlayPosition")
        let keepAliveType = notification != nil ? "bluetooth_\(notification!.id)" : "bluetooth"
        
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
            customHeight: 56,
            supportDragGesture: false,
            onSimpleTap: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    if !isExpanded && actualIsConnected {
                        mediaKeyManager.fetchBluetoothDetails()
                    }
                }
            },
            isExpandable: bluetoothAllowExpansion,
            expandUpwards: btPos.hasPrefix("bottom"),
            keepAliveId: keepAliveType,
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
                    } else if actualIsConnected {
                        if !effectiveDeviceBatteries.isEmpty {
                            VStack(spacing: 12) {
                                HStack(spacing: 24) {
                                    Spacer()
                                    let sortedBatteries = effectiveDeviceBatteries.sorted { sortWeight(for: $0.key) < sortWeight(for: $1.key) }
                                    
                                    ForEach(sortedBatteries, id: \.key) { key, battery in
                                        let suffix = key.replacingOccurrences(of: systemName, with: "").trimmingCharacters(in: .whitespaces)
                                        
                                        let batteryIcon: String = {
                                            if battery >= 85 { return "battery.100" }
                                            if battery >= 60 { return "battery.75" }
                                            if battery >= 35 { return "battery.50" }
                                            if battery >= 15 { return "battery.25" }
                                            return "battery.0"
                                        }()
                                        
                                        VStack(spacing: 6) {
                                            Image(systemName: iconFor(suffix: suffix, deviceName: systemName))
                                                .font(.system(size: 26))
                                                .foregroundColor(.primary)
                                                .frame(height: 32)
                                                
                                            Image(systemName: batteryIcon)
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                                
                                            Text("\(battery)%")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.primary)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                                
                                Button(action: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        showDetails.toggle()
                                    }
                                }) {
                                    Text(showDetails ? "Hide Details" : "Show Details")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(Color.primary.opacity(0.1))
                                        .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                                .onHover { hovering in
                                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                }
                            }
                            
                            if showDetails {
                                Divider()
                                    .padding(.horizontal, 32)
                                    .opacity(0.3)
                            }
                        }
                        
                        if showDetails || effectiveDeviceBatteries.isEmpty {
                            VStack(spacing: 8) {
                                if let details = isPreview ? ["MAC": "00:11:22:33:44:55", "Typ": "Headphones", "Firmware": "1.0.0", "RSSI": "-45 dBm", "SystemName": "AirPods Pro"] : mediaKeyManager.bluetoothDetails[deviceId] {
                                    if let mac = details["MAC"] {
                                        StatRow(icon: "network", label: "MAC Address", value: mac, allowShrink: true)
                                    }
                                    if let type = details["Typ"] {
                                        StatRow(icon: "tag", label: "Type", value: type)
                                    }
                                    if let fw = details["Firmware"] {
                                        StatRow(icon: "cpu", label: "Firmware", value: fw)
                                    }
                                    if let rssi = details["RSSI"] {
                                        StatRow(icon: "antenna.radiowaves.left.and.right", label: "Signal", value: rssi)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, effectiveDeviceBatteries.isEmpty ? 0 : 4)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        if actualIsConnected {
                            Button(action: {
                                if !isPreview {
                                    mediaKeyManager.disconnectBluetoothDevice(macAddress: deviceId)
                                }
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                    isExpanded = false
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("Disconnect")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(28 - 4 - 3)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Button(action: {
                            if !isPreview {
                                mediaKeyManager.openBluetoothSettings()
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                    isExpanded = false
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "gear")
                                Text(actualIsConnected ? "Settings" : "Bluetooth Settings")
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
                    
                    .padding(.top, 4)
                }
            }
        )

                .onChange(of: isExpanded) { _, expanded in
            if expanded && actualIsConnected {
                refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                    mediaKeyManager.fetchBluetoothDetails()
                }
            } else {
                refreshTimer?.invalidate()
                refreshTimer = nil
                showDetails = false
            }
        }
    }
}
