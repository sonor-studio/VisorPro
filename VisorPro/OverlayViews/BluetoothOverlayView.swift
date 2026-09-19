import SwiftUI
import IOBluetooth

struct BluetoothOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @EnvironmentObject var overlayState: OverlayStateRelay
    @AppStorage("bluetoothAllowExpansion") private var bluetoothAllowExpansion: Bool = true
    @State private var isHovering = false
    @State private var refreshTimer: Timer?
    @State private var isExpanded: Bool = false
    @State private var showDetails: Bool = false
    @State private var hasWaitedForDetails: Bool = false
    @State private var isDisconnecting: Bool = false
    var isPreview: Bool = false
    var previewIsAccessory: Bool = false
    var previewIsConnected: Bool = true
    var previewDeviceName: String = "AirPods Pro"
    var notification: DeviceNotification?
    
    private var actualIsConnected: Bool {
        if isPreview { return previewIsConnected }
        if let notif = notification { return notif.isConnected }
        return overlayState.bluetoothIsConnected // Fallback if needed
    }
    
    private var actualDeviceName: String {
        if isPreview { return previewDeviceName }
        if let notif = notification { return notif.deviceName }
        return overlayState.bluetoothDeviceName
    }
    
    private var actionColor: Color {
        if mediaKeyManager.overlayColorMode == "custom", (isPreview && previewIsAccessory) || notification?.type == "accessory" || actualDeviceName.lowercased().contains("airpods") || notification?.id == "AIRPODS_CONNECTION" {
            let baseName = actualDeviceName
            var settings = mediaKeyManager.accessorySettings[baseName]
            
            if settings == nil, (actualDeviceName.lowercased().contains("airpods") || notification?.id == "AIRPODS_CONNECTION") {
                settings = mediaKeyManager.accessorySettings.first(where: { $0.key.lowercased().contains("airpods") })?.value
            }
            if settings == nil {
                settings = mediaKeyManager.accessorySettings.first(where: { $0.key.lowercased() == baseName.lowercased() })?.value
            }
            if settings == nil, let notifName = notification?.deviceName {
                settings = mediaKeyManager.accessorySettings.first(where: { $0.key.lowercased() == notifName.lowercased() })?.value
            }
            
            let finalSettings = settings ?? AccessoryDeviceSettings()
            
            if actualIsConnected && finalSettings.colorOnConnect != "Default" { return OverlayColorManager.shared.parseColor(finalSettings.colorOnConnect) }
            if !actualIsConnected && finalSettings.colorOnDisconnect != "Default" { return OverlayColorManager.shared.parseColor(finalSettings.colorOnDisconnect) }
        }
        return actualIsConnected ? OverlayColorManager.shared.getOverlayColor(for: "colorOnBluetoothConnect", defaultColor: .indigo) : .secondary
    }
    
    private var actionTitle: String {
        let name = actualDeviceName.lowercased()
        let deviceId = isPreview ? "00:11:22:33:44:55" : (notification?.id ?? "")
        let typeInfo = isPreview ? (name.contains("mouse") ? "mouse" : (name.contains("keyboard") ? "keyboard" : "headphones")) : (mediaKeyManager.bluetoothDetails[deviceId]?["Typ"]?.lowercased() ?? "")
        
        let prefix: String
        
        if let notif = notification, notif.id == "AIRPODS_CONNECTION" {
            prefix = "AirPods"
        } else if name.contains("airpods") {
            prefix = "AirPods"
        } else if name.contains("iphone") {
            prefix = "iPhone"
        } else if name.contains("ipad") {
            prefix = "iPad"
        } else if name.contains("headphones") || name.contains("słuchawki") || name.contains("headset") || typeInfo.contains("headphones") || typeInfo.contains("słuchawki") {
            prefix = "Headphones"
        } else if name.contains("mouse") || name.contains("mysz") || typeInfo.contains("mouse") {
            prefix = "Mouse"
        } else if name.contains("keyboard") || name.contains("klawiatura") || typeInfo.contains("keyboard") {
            prefix = "Keyboard"
        } else if name.contains("trackpad") || typeInfo.contains("trackpad") {
            prefix = "Trackpad"
        } else if (isPreview && previewIsAccessory) || notification?.type == "accessory" {
            prefix = "Accessory"
        } else {
            prefix = "Bluetooth"
        }
        
        return actualIsConnected ? "\(prefix) Connected" : "\(prefix) Disconnected"
    }
    
    private func iconFor(suffix: String, deviceName: String, fallbackIcon: String? = nil) -> String {
        let lowerSuffix = suffix.lowercased()
        let lowerName = deviceName.lowercased()
        
        if lowerSuffix.contains("left") || lowerSuffix.contains("lewa") {
            return "airpodpro.left"
        } else if lowerSuffix.contains("right") || lowerSuffix.contains("prawa") {
            return "airpodpro.right"
        } else if lowerSuffix.contains("case") || lowerSuffix.contains("etui") {
            return "airpodspro.chargingcase.wireless.fill"
        }
        
        if let fallback = fallbackIcon, fallback != "bolt.batteryblock.fill" {
            return fallback
        }
        
        if lowerName.contains("mouse") || lowerName.contains("mysz") {
            return "magicmouse"
        } else if lowerName.contains("keyboard") || lowerName.contains("klawiatura") {
            return "keyboard"
        } else if lowerName.contains("trackpad") {
            return "magicpad"
        } else if lowerName.contains("iphone") {
            return "iphone"
        } else if lowerName.contains("ipad") {
            return "ipad"
        } else if lowerName.contains("macbook") {
            return "macbook"
        } else if lowerName.contains("watch") {
            return "applewatch"
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
        let isAirPods = notification?.id == "AIRPODS_CONNECTION" || actualDeviceName.lowercased().contains("airpods")
        
        let resolvedDetails: [String: String]? = {
            if isPreview { 
                var type = "Device"
                if actualDeviceName.lowercased().contains("mouse") { type = "Mouse" }
                else if actualDeviceName.lowercased().contains("keyboard") { type = "Keyboard" }
                else if actualDeviceName.lowercased().contains("iphone") { type = "iPhone" }
                else if actualDeviceName.lowercased().contains("ipad") { type = "iPad" }
                else { type = "Headphones" } // Default to headphones for preview
                return ["MAC": "00:11:22:33:44:55", "Typ": type, "Firmware": "1.0.0", "RSSI": "-45 dBm", "SystemName": actualDeviceName] 
            }
            if let directDetails = mediaKeyManager.bluetoothDetails[deviceId] { return directDetails }
            if isAirPods {
                if let match = mediaKeyManager.bluetoothDetails.first(where: { $0.value["SystemName"]?.lowercased().contains("airpods") == true }) {
                    return match.value
                }
            }
            return nil
        }()
        
        let hasDetails = isPreview ? MediaKeyManager.shared.isBluetoothAccessory(actualDeviceName) : resolvedDetails != nil
        let hasRealDetails = isPreview ? true : (resolvedDetails != nil && !resolvedDetails!.isEmpty)
        
        let resolvedSystemName = resolvedDetails?["SystemName"] ?? ""
        let systemName = resolvedSystemName.isEmpty ? actualDeviceName : resolvedSystemName
        
        let currentAccessorySettings: AccessoryDeviceSettings = {
            var settings = mediaKeyManager.accessorySettings[actualDeviceName]
            if settings == nil, (actualDeviceName.lowercased().contains("airpods") || notification?.id == "AIRPODS_CONNECTION") {
                settings = mediaKeyManager.accessorySettings.first(where: { $0.key.lowercased().contains("airpods") })?.value
            }
            if settings == nil {
                settings = mediaKeyManager.accessorySettings.first(where: { $0.key.lowercased() == actualDeviceName.lowercased() })?.value
            }
            if settings == nil, let notifName = notification?.deviceName {
                settings = mediaKeyManager.accessorySettings.first(where: { $0.key.lowercased() == notifName.lowercased() })?.value
            }
            return settings ?? AccessoryDeviceSettings()
        }()
        
        let deviceBatteries = overlayState.accessoryBatteryLevels.filter { $0.key.hasPrefix(systemName) }
        var effectiveDeviceBatteries: [String: Int] = isPreview ? (
            actualDeviceName.lowercased().contains("airpods") ? [
                "\(systemName) (Left)": 85,
                "\(systemName) (Right)": 100,
                "\(systemName) (Case)": 20
            ] : [
                "\(systemName)": 85
            ]
        ) : deviceBatteries.reduce(into: [:]) { $0[$1.key] = $1.value }
        
        if isAirPods && !isPreview {
            effectiveDeviceBatteries.removeAll()
            let left = overlayState.airpodsLeftBattery
            let right = overlayState.airpodsRightBattery
            let caseBat = overlayState.airpodsCaseBattery
            if left > 0 { effectiveDeviceBatteries["\(systemName) (Left)"] = left }
            if right > 0 { effectiveDeviceBatteries["\(systemName) (Right)"] = right }
            if caseBat > 0 { effectiveDeviceBatteries["\(systemName) (Case)"] = caseBat }
        }
        
        let isAccessoryType = (isPreview && previewIsAccessory) || notification?.type == "accessory" || isAirPods
        
        let averageBattery: Int? = {
            if effectiveDeviceBatteries.isEmpty { return nil }
            let earbudBatteries = effectiveDeviceBatteries.filter { $0.key.lowercased().contains("left") || $0.key.lowercased().contains("right") || $0.key.lowercased().contains("lewa") || $0.key.lowercased().contains("prawa") }
            if !earbudBatteries.isEmpty {
                return earbudBatteries.values.reduce(0, +) / earbudBatteries.count
            }
            if isAirPods { return nil }
            return effectiveDeviceBatteries.values.reduce(0, +) / effectiveDeviceBatteries.count
        }()
        
        let accessoryBatteryColor: Color = {
            if mediaKeyManager.overlayColorMode == "custom", isAccessoryType || actualDeviceName.lowercased().contains("airpods") || notification?.id == "AIRPODS_CONNECTION" {
                if actualIsConnected && currentAccessorySettings.colorOnConnect != "Default" { return OverlayColorManager.shared.parseColor(currentAccessorySettings.colorOnConnect) }
                if !actualIsConnected && currentAccessorySettings.colorOnDisconnect != "Default" { return OverlayColorManager.shared.parseColor(currentAccessorySettings.colorOnDisconnect) }
            }
            return MediaKeyManager.shared.isBluetoothAccessory(actualDeviceName)
                ? OverlayColorManager.shared.getOverlayColor(for: "colorOnBluetoothConnect", defaultColor: .indigo)
                : OverlayColorManager.shared.getOverlayColor(for: "colorOnPeripheralConnect", defaultColor: .blue)
        }()
        
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
        let typeInfo = isPreview ? "headphones" : (mediaKeyManager.bluetoothDetails[deviceId]?["Typ"]?.lowercased() ?? "")
        
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
            if nameLower.contains("mouse") || typeInfo.contains("mouse") { return "magicmouse" }
            if nameLower.contains("keyboard") || typeInfo.contains("keyboard") { return "keyboard" }
            if nameLower.contains("trackpad") || typeInfo.contains("trackpad") { return "magicmouse" }
            if nameLower.contains("iphone") || typeInfo.contains("iphone") { return "iphone" }
            if nameLower.contains("ipad") || typeInfo.contains("ipad") { return "ipad" }
            if nameLower.contains("mac") || typeInfo.contains("mac") { return "macbook" }
            if nameLower.contains("watch") || typeInfo.contains("watch") { return "applewatch" }
            if nameLower.contains("controller") || nameLower.contains("pad") || typeInfo.contains("gamepad") { return "gamecontroller.fill" }
            if nameLower.contains("headphone") || nameLower.contains("słuchawki") || nameLower.contains("buds") || nameLower.contains("ear") || typeInfo.contains("headphones") || typeInfo.contains("słuchawki") { return "headphones" }
            if nameLower.contains("speaker") || typeInfo.contains("speaker") { return "speaker.wave.2" }
            return "point.3.connected.trianglepath.dotted"
        }()
        
        let btPos = MediaKeyManager.shared.getOverlayPosition(for: "bluetoothOverlayPosition")
        let keepAliveType = notification != nil ? "bluetooth_\(notification!.id)" : "bluetooth"
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            progress: (isAccessoryType && actualIsConnected && averageBattery != nil) ? CGFloat(averageBattery!) / 100.0 : 1.0,
            hasTimeoutProgress: (isAccessoryType && actualIsConnected && averageBattery != nil) ? false : true,
            timeoutEventId: notification?.timestamp ?? Date(timeIntervalSince1970: 0),
            barColor: isAccessoryType && actualIsConnected ? accessoryBatteryColor : (actualIsConnected ? OverlayColorManager.shared.getOverlayColor(for: "colorOnBluetoothConnect", defaultColor: .indigo) : .offStateGray),
            fillCenter: false,
            isMuted: false,
            customWidth: 260,
            customHeight: 56,
            supportDragGesture: false,
            onSimpleTap: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if !isExpanded && actualIsConnected {
                        mediaKeyManager.fetchBluetoothDetails()
                    }
                }
            },
            isExpandable: bluetoothAllowExpansion,
            expandUpwards: btPos.hasPrefix("bottom"),
            keepAliveId: keepAliveType,
            disableTimeoutMode: isAccessoryType && actualIsConnected && averageBattery != nil,
            baseContent: {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(actualIsConnected ? .primary : .secondary)
                        .frame(width: 26, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(actionTitle)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        MarqueeText(text: actualDeviceName.isEmpty ? "Unknown Device" : actualDeviceName, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 8)
                    
                    if isAccessoryType && actualIsConnected, let bat = averageBattery {
                        Text("\(bat)%")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .padding(.leading, 23)
                .padding(.trailing, isAccessoryType ? 23 : 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            },
            expandedContent: {
                VStack(spacing: 12) {
                    Divider()
                        .padding(.horizontal, 16)
                        .opacity(0.5)
                    
                    if actualIsConnected && !hasDetails && effectiveDeviceBatteries.isEmpty && !isAccessoryType {
                        if hasWaitedForDetails {
                            Text("No details available")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(.vertical, 12)
                        } else {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(height: 50)
                        }
                    } else if actualIsConnected {
                        if !effectiveDeviceBatteries.isEmpty && currentAccessorySettings.showBattery {
                            VStack(spacing: 12) {
                                let sortedBatteries = effectiveDeviceBatteries.sorted { sortWeight(for: $0.key) < sortWeight(for: $1.key) }
                                
                                if sortedBatteries.count == 1 {
                                    let key = sortedBatteries[0].key
                                    let battery = sortedBatteries[0].value
                                    let suffix = key.replacingOccurrences(of: systemName, with: "").trimmingCharacters(in: .whitespaces)
                                    let batteryIcon: String = {
                                        if battery >= 85 { return "battery.100" }
                                        if battery >= 60 { return "battery.75" }
                                        if battery >= 35 { return "battery.50" }
                                        if battery >= 15 { return "battery.25" }
                                        return "battery.0"
                                    }()
                                    let isCharging = mediaKeyManager.accessoryBatteryCharging[key] == true
                                    
                                    HStack(spacing: 16) {
                                        Image(systemName: isCharging ? "bolt.fill" : batteryIcon)
                                            .font(.system(size: 20, weight: .regular))
                                            .foregroundColor(isCharging ? .green : (battery <= 20 ? .red : .primary))
                                            .frame(width: 36, height: 36)
                                            .background(Color.secondary.opacity(0.1))
                                            .cornerRadius(8)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Battery")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.primary)
                                            
                                            Text(isCharging ? "Charging" : "Remaining")
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Text("\(battery)%")
                                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 4)
                                } else {
                                    HStack(spacing: 24) {
                                        Spacer()
                                        
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
                                                Image(systemName: iconFor(suffix: suffix, deviceName: systemName, fallbackIcon: iconName))
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
                                }
                                if hasRealDetails && currentAccessorySettings.showDetails {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
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
                                    .pointingHandCursor()
                                }
                            }
                            
                            if hasRealDetails && currentAccessorySettings.showDetails && showDetails {
                                Divider()
                                    .padding(.horizontal, 32)
                                    .opacity(0.3)
                            }
                        }
                        
                        if hasRealDetails && currentAccessorySettings.showDetails && (showDetails || (effectiveDeviceBatteries.isEmpty || !currentAccessorySettings.showBattery)) {
                            VStack(spacing: 8) {
                                if let details = resolvedDetails {
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
                    } else {
                        if hasRealDetails && currentAccessorySettings.showDetails {
                            VStack(spacing: 8) {
                                if let details = resolvedDetails {
                                    if let mac = details["MAC"] {
                                        StatRow(icon: "network", label: "MAC Address", value: mac, allowShrink: true)
                                    }
                                    if let type = details["Typ"] {
                                        StatRow(icon: "tag", label: "Type", value: type)
                                    }
                                    if let fw = details["Firmware"] {
                                        StatRow(icon: "cpu", label: "Firmware", value: fw)
                                    }
                                    // RSSI is not relevant when disconnected
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        if actualIsConnected {
                            Button(action: {
                                if !isPreview {
                                    isDisconnecting = true
                                    let macToDisconnect = resolvedDetails?["MAC"] ?? deviceId
                                    mediaKeyManager.disconnectBluetoothDevice(macAddress: macToDisconnect, deviceName: actualDeviceName)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark.circle.fill")
                                    Text(isDisconnecting ? "Disconnecting" : "Disconnect")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(28 - 4 - 3)
                            }
                            .buttonStyle(.plain)
                            .conditionalPointingHandCursor(isEnabled: !isDisconnecting)
                            .disabled(isDisconnecting)
                        }
                        
                        Button(action: {
                            if !isPreview {
                                mediaKeyManager.openBluetoothSettings()
                                withAnimation(.easeInOut(duration: 0.2)) {
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
                        .pointingHandCursor()
                    }
                    .padding(.horizontal, 16)
                    
                    .padding(.top, 4)
                }
            }
        )
        .id(notification?.timestamp ?? Date(timeIntervalSince1970: 0))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                hasWaitedForDetails = true
            }
        }
        .onChange(of: isExpanded) { _, expanded in
            if expanded && actualIsConnected {
                refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                    mediaKeyManager.fetchBluetoothDetails()
                }
            } else {
                refreshTimer?.invalidate()
                refreshTimer = nil
                showDetails = false
                isDisconnecting = false
            }
        }
    }
}
