import SwiftUI
import Combine

struct PeripheralOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @State private var isExpanded: Bool = false
    @AppStorage("peripheralAllowExpansion") private var peripheralAllowExpansion: Bool = true
    @State private var isEjecting = false
    @State private var isEjected = false
    @State private var isMounting = false
    @State private var unmountedDeviceNode: String? = nil
    
    @State private var driveTotalSpace: String? = nil
    @State private var driveFreeSpace: String? = nil
    @State private var rawDriveTotal: Int64? = nil
    @State private var rawDriveFree: Int64? = nil
    @State private var showMoreDetails: Bool = false
    @State private var refreshTimer: Timer? = nil
    @State private var isOpticalEmpty: Bool = false
    
    var isPreview: Bool = false
    var previewIsConnected: Bool = false
    var notification: DeviceNotification?
    
    var actualNotification: DeviceNotification? {
        if isPreview {
            return DeviceNotification(
                id: "preview_disk",
                deviceName: "SanDisk Extreme",
                type: "USB Drive",
                icon: "externaldrive.fill",
                isConnected: previewIsConnected,
                timestamp: Date(timeIntervalSince1970: 0),
                details: [
                    "Vendor": "SanDisk",
                    "Product": "Extreme SSD",
                    "Speed": "SuperSpeed (5 Gbps)",
                    "Format": "APFS"
                ]
            )
        }
        return notification
    }
    
    var isConnected: Bool {
        if let notif = actualNotification { return notif.isConnected }
        return mediaKeyManager.peripheralIsConnected
    }
    
    var deviceName: String {
        if let notif = actualNotification { return notif.deviceName }
        return mediaKeyManager.peripheralDeviceName
    }
    
    var iconName: String {
        if let notif = actualNotification {
            let lower = notif.deviceName.lowercased()
            let lowerType = notif.type.lowercased()
            if notif.icon != "cable.connector" && !notif.icon.isEmpty {
                return notif.icon
            }
            if lower.contains("iphone") || lowerType.contains("iphone") { return "iphone" }
            if lower.contains("ipad") || lowerType.contains("ipad") { return "ipad" }
            if lower.contains("ipod") || lowerType.contains("ipod") { return "ipod" }
            if lower.contains("mouse") { return "magicmouse" }
            if lower.contains("keyboard") { return "keyboard" }
            if lower.contains("headphones") || lower.contains("audio") { return "headphones" }
            return notif.icon
        }
        return mediaKeyManager.peripheralDeviceIcon
    }
    
    private var batteryLevel: Int? {
        if isPreview { return 85 }
        if let raw = actualNotification?.details?["BatteryLevel"], let val = Int(raw) {
            return val
        }
        if let rawBat = actualNotification?.details?["Battery"] {
            let digits = rawBat.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let val = Int(digits) { return val }
        }
        if let val = mediaKeyManager.accessoryBatteryLevels[deviceName] {
            return val
        }
        return nil
    }
    
    private var isBatteryCharging: Bool {
        if isPreview { return true }
        if let ch = actualNotification?.details?["Charging"] {
            return ch.lowercased().contains("yes") || ch.lowercased().contains("true")
        }
        if let val = mediaKeyManager.accessoryBatteryCharging[deviceName] {
            return val
        }
        return isConnected
    }
    
    private func batteryDeviceIcon(for deviceName: String, type: String) -> String {
        let lowerName = deviceName.lowercased()
        let lowerType = type.lowercased()
        if lowerName.contains("iphone") || lowerType.contains("iphone") { return "iphone" }
        if lowerName.contains("ipad") || lowerType.contains("ipad") { return "ipad" }
        if lowerName.contains("ipod") || lowerType.contains("ipod") { return "ipod" }
        if lowerName.contains("mouse") || lowerName.contains("mysz") { return "magicmouse.fill" }
        if lowerName.contains("keyboard") || lowerName.contains("klawiatura") { return "keyboard.fill" }
        if lowerName.contains("trackpad") { return "magicmouse.fill" }
        if lowerName.contains("headphone") || lowerName.contains("audio") { return "headphones" }
        if lowerName.contains("watch") { return "applewatch" }
        return iconName
    }
    
    var body: some View {
        let actionColor: Color = isConnected ? Color(red: 0.85, green: 0.15, blue: 0.55) : .secondary
        let periPos = MediaKeyManager.shared.getOverlayPosition(for: "peripheralOverlayPosition")
        
        let type = actualNotification?.type ?? ""
        let typeIcon = actualNotification?.icon ?? ""
        
        let hasBattery = (batteryLevel != nil) && isConnected
        let isDriveType = (type == "USB Drive" || typeIcon == "externaldrive" || type == "CD/DVD Drive")
        let isDrive = driveTotalSpace != nil || isDriveType
        let hasDetails = (actualNotification?.details?.isEmpty == false) || isDrive
        let isExpandable = (hasDetails || isDrive || hasBattery) && isConnected
        
        let keepAliveId = actualNotification != nil ? "peripheral_\(actualNotification!.id)" : "peripheral"
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            hasTimeoutProgress: true,
            timeoutEventId: actualNotification?.timestamp ?? Date(timeIntervalSince1970: 0),
            barColor: actionColor,
            fillCenter: false, // uses strokeBorder
            isMuted: false,
            customWidth: 260,
            supportDragGesture: false,
            isExpandable: isExpandable && peripheralAllowExpansion,
            expandUpwards: periPos.hasPrefix("bottom"),
            keepAliveId: keepAliveId,
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
                        Divider()
                            .padding(.horizontal, 16)
                            .opacity(0.5)
                        
                        if hasBattery, let battery = batteryLevel {
                            VStack(spacing: 12) {
                                HStack(spacing: 24) {
                                    Spacer()
                                    
                                    let batteryIcon: String = {
                                        if battery >= 85 { return "battery.100" }
                                        if battery >= 60 { return "battery.75" }
                                        if battery >= 35 { return "battery.50" }
                                        if battery >= 15 { return "battery.25" }
                                        return "battery.0"
                                    }()
                                    
                                    VStack(spacing: 6) {
                                        Image(systemName: batteryDeviceIcon(for: deviceName, type: type))
                                            .font(.system(size: 26))
                                            .foregroundColor(.primary)
                                            .frame(height: 32)
                                            
                                        HStack(spacing: 3) {
                                            Image(systemName: batteryIcon)
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                            if isBatteryCharging {
                                                Image(systemName: "bolt.fill")
                                                    .font(.system(size: 8))
                                                    .foregroundColor(.green)
                                            }
                                        }
                                            
                                        Text("\(battery)%")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        
                        if hasDetails {
                            VStack(spacing: 8) {
                                if let total = driveTotalSpace, let freeStr = driveFreeSpace, let rawTotal = rawDriveTotal, let rawFree = rawDriveFree, rawTotal > 0 {
                                    let used = rawTotal - rawFree
                                    let percentage = CGFloat(used) / CGFloat(rawTotal)
                                    let tint: Color = percentage > 0.9 ? .red : (percentage > 0.75 ? .orange : actionColor)
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(alignment: .lastTextBaseline) {
                                            Text(total)
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Text("\(freeStr) free")
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                Capsule()
                                                    .fill(Color.primary.opacity(0.1))
                                                    .frame(height: 6)
                                                
                                                Capsule()
                                                    .fill(tint)
                                                    .frame(width: max(0, geo.size.width * min(percentage, 1.0)), height: 6)
                                            }
                                        }
                                        .frame(height: 6)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 4)
                                } else if isDriveType && isConnected && !isEjected {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(alignment: .lastTextBaseline) {
                                            if isOpticalEmpty {
                                                Text("No Media Inserted")
                                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                                    .foregroundColor(.secondary)
                                            } else {
                                                Text("Calculating size...")
                                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                                    .foregroundColor(.secondary)
                                                Spacer()
                                                ProgressView()
                                                    .scaleEffect(0.5)
                                                    .frame(width: 12, height: 12)
                                            }
                                        }
                                        
                                        Capsule()
                                            .fill(Color.primary.opacity(0.1))
                                            .frame(height: 6)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 4)
                                }
                                
                                let allKeys = actualNotification?.details?.keys.filter { $0 != "BSD Name" && $0 != "BatteryLevel" && (!hasBattery || ($0 != "Battery" && $0 != "Charging")) }.sorted(by: >) ?? []
                                let vendorKey = allKeys.contains("Vendor") ? ["Vendor"] : []
                                let otherKeys = allKeys.filter { $0 != "Vendor" }
                                
                                let shouldHideDetailsBehindButton = (hasBattery || isDrive)
                                
                                if !otherKeys.isEmpty && shouldHideDetailsBehindButton {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                            showMoreDetails.toggle()
                                        }
                                    }) {
                                        Text(showMoreDetails ? "Hide Details" : "Show Details")
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
                                    .padding(.top, 4)
                                }
                                
                                // Vendor always visible BELOW the button
                                ForEach(vendorKey, id: \.self) { key in
                                    if let value = actualNotification?.details?[key] {
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
                                
                                if (!shouldHideDetailsBehindButton || showMoreDetails) && !otherKeys.isEmpty {
                                    if shouldHideDetailsBehindButton {
                                        Divider()
                                            .padding(.horizontal, 32)
                                            .opacity(0.3)
                                    }
                                        
                                    ForEach(otherKeys, id: \.self) { key in
                                        if let value = actualNotification?.details?[key] {
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
                                }
                            }
                        }
                        
                        if isDrive && driveTotalSpace != nil {
                            VStack(spacing: 8) {
                                if !isConnected || isEjected {
                                    Button(action: {
                                        if !isPreview {
                                            isMounting = true
                                            if let node = unmountedDeviceNode {
                                                mediaKeyManager.mountDrive(deviceNode: node) { success in
                                                    isMounting = false
                                                    if success {
                                                        isEjected = false
                                                        unmountedDeviceNode = nil
                                                        fetchDriveCapacity(type: type, typeIcon: typeIcon)
                                                    }
                                                }
                                            } else {
                                                isMounting = false
                                            }
                                        } else {
                                            isMounting = true
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                isMounting = false
                                                isEjected = false
                                                fetchDriveCapacity(type: type, typeIcon: typeIcon)
                                            }
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            if isMounting {
                                                ProgressView()
                                                    .scaleEffect(0.5)
                                                    .frame(width: 12, height: 12)
                                                Text("Mounting...")
                                            } else {
                                                Image(systemName: "externaldrive.connected.to.line.below")
                                                Text("Mount Drive")
                                            }
                                        }
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.primary.opacity(0.1))
                                        .cornerRadius(28 - 4 - 3)
                                    }
                                    .disabled(isMounting || (unmountedDeviceNode == nil && !isPreview))
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 16)
                                } else {
                                    HStack(spacing: 8) {
                                        Button(action: {
                                            if !isPreview, let notif = actualNotification {
                                                mediaKeyManager.openDrive(for: notif)
                                            }
                                        }) {
                                            HStack(spacing: 4) {
                                                if type == "CD/DVD Drive" {
                                                    Image(systemName: "play.circle")
                                                    Text("Play Disc")
                                                } else {
                                                    Image(systemName: "folder")
                                                    Text("Open in Finder")
                                                }
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
                                            if !isPreview, let notif = actualNotification {
                                                isEjecting = true
                                                mediaKeyManager.ejectDrive(for: notif) { success, node in
                                                    isEjecting = false
                                                    if success {
                                                        unmountedDeviceNode = node
                                                        isEjected = true
                                                    }
                                                }
                                            } else {
                                                isEjecting = true
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                    isEjecting = false
                                                    isEjected = true
                                                }
                                            }
                                        }) {
                                            HStack(spacing: 4) {
                                                if isEjecting {
                                                    ProgressView()
                                                        .scaleEffect(0.5)
                                                        .frame(width: 12, height: 12)
                                                    Text("Ejecting...")
                                                } else {
                                                    Image(systemName: "eject")
                                                    Text("Eject")
                                                }
                                            }
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(Color.primary.opacity(0.1))
                                            .cornerRadius(28 - 4 - 3)
                                        }
                                        .disabled(isEjecting)
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                            
                            .padding(.top, 4)
                        } else if hasDetails {
                            
                        }
                    }
                } else {
                    EmptyView()
                }
            }
        )
        .id(actualNotification?.timestamp ?? Date(timeIntervalSince1970: 0))
        .onChange(of: isExpanded) { _, expanded in
            if !isPreview {
                let currentType = actualNotification?.type ?? ""
                let currentIcon = actualNotification?.icon ?? ""
                let currentIsDrive = currentType == "USB Drive" || currentIcon == "externaldrive" || currentType == "USB Device" || currentType == "CD/DVD Drive"
                
                if expanded && currentIsDrive && isConnected {
                    refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                        fetchDriveCapacity(type: currentType, typeIcon: currentIcon)
                    }
                } else {
                    refreshTimer?.invalidate()
                    refreshTimer = nil
                }
            }
        }
        .onChange(of: actualNotification?.isConnected) { _, connected in
            if connected == false {
                isExpanded = false
            }
        }
        .onChange(of: actualNotification?.timestamp) { _, _ in
            // When a new event happens for this device (like physically replugging), reset the manual mount/eject states
            if actualNotification?.isConnected == true {
                isEjected = false
                isEjecting = false
                isMounting = false
                unmountedDeviceNode = nil
                driveTotalSpace = nil
                driveFreeSpace = nil
                rawDriveTotal = nil
                rawDriveFree = nil
            }
        }
        .onAppear {
            if isPreview {
                driveTotalSpace = "2 TB"
                driveFreeSpace = "850 GB"
                rawDriveTotal = 2_000_000_000_000
                rawDriveFree = 850_000_000_000
            } else {
                fetchDriveCapacity(type: type, typeIcon: typeIcon)
            }
        }
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            if isConnected && !isEjected && driveTotalSpace == nil && (type == "USB Drive" || typeIcon == "externaldrive" || type == "USB Device" || type == "CD/DVD Drive") {
                fetchDriveCapacity(type: type, typeIcon: typeIcon)
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }
    
    private func fetchDriveCapacity(type: String, typeIcon: String) {
        if type == "CD/DVD Drive" && isConnected {
            DispatchQueue.global(qos: .userInitiated).async {
                let empty = mediaKeyManager.hasOpticalMedia() == false
                DispatchQueue.main.async {
                    if self.isOpticalEmpty != empty {
                        self.isOpticalEmpty = empty
                    }
                }
            }
        }
        
        if type == "USB Drive" || typeIcon == "externaldrive" || type == "USB Device" || type == "CD/DVD Drive",
           let notif = actualNotification,
           let cap = mediaKeyManager.getDriveCapacity(for: notif) {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            self.driveTotalSpace = formatter.string(fromByteCount: Int64(cap.total))
            self.driveFreeSpace = formatter.string(fromByteCount: Int64(cap.available))
            self.rawDriveTotal = Int64(cap.total)
            self.rawDriveFree = Int64(cap.available)
        }
    }
}

struct PeripheralMockDetail: Identifiable {
    let id: String
    let value: String
}
