import SwiftUI
import Combine

struct PeripheralOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @State private var isHovering: Bool = false
    @State private var isExpanded: Bool = false
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
        
        let type = notification?.type ?? ""
        let typeIcon = notification?.icon ?? ""
        
        var calcHeight: CGFloat = 0
        let hasDetails = isPreview || (notification?.details?.isEmpty == false) || (driveTotalSpace != nil)
        let isDrive = type == "USB Drive" || typeIcon == "externaldrive" || type == "USB Device"
        let isExpandable = (hasDetails || isDrive) && isConnected
        
        if isExpandable {
            calcHeight += 12 // Divider and spacing
            
            if hasDetails {
                calcHeight += 12 // Spacing before details
                
                if driveTotalSpace != nil {
                    calcHeight += 38 // Capacity height
                }
                
                let detailsCount = isPreview ? 5 : CGFloat((notification?.details?.count ?? 0) - (notification?.details?["BSD Name"] != nil ? 1 : 0))
                
                if detailsCount > 0 {
                    if showMoreDetails {
                        calcHeight += (detailsCount * 16) + (max(detailsCount - 1, 0) * 8)
                        calcHeight += 36 // padding + button + divider
                    } else {
                        let hasVendor = isPreview || notification?.details?.keys.contains("Vendor") == true
                        if hasVendor {
                            calcHeight += 16
                        }
                        if detailsCount > 1 {
                            calcHeight += 31 // padding + button
                        }
                    }
                }
            }
            if isDrive {
                calcHeight += 14 // Spacing before buttons
                calcHeight += 50 // buttons: 4 top, 30 content, 16 bottom
            } else if hasDetails {
                calcHeight += 14 // Spacing before clear frame
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
                TimeoutProgressBar(trackWidth: trackWidth, isHovering: isHovering || isExpanded, initialDuration: MediaKeyManager.notificationDuration, hoverOutDuration: MediaKeyManager.notificationDuration)
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
                        Divider()
                            .padding(.horizontal, 16)
                            .opacity(0.5)
                        
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
                                }
                                
                                let allKeys = notification?.details?.keys.filter { $0 != "BSD Name" }.sorted(by: >) ?? []
                                let vendorKey = allKeys.contains("Vendor") ? ["Vendor"] : []
                                
                                // Show Vendor first (if exists)
                                ForEach(vendorKey, id: \.self) { key in
                                    if let value = notification?.details?[key] {
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
                                
                                if allKeys.count > 1 {
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
                                    
                                    if showMoreDetails {
                                        Divider()
                                            .padding(.horizontal, 32)
                                            .opacity(0.3)
                                            
                                        let otherKeys = allKeys.filter { $0 != "Vendor" }
                                        ForEach(otherKeys, id: \.self) { key in
                                            if let value = notification?.details?[key] {
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
                                
                                if isPreview {
                                    let mockDetails = [
                                        PeripheralMockDetail(id: "Vendor", value: "Apple Inc."),
                                        PeripheralMockDetail(id: "Product", value: "Magic Mouse"),
                                        PeripheralMockDetail(id: "Speed", value: "High (480 Mbps)"),
                                        PeripheralMockDetail(id: "Device ID", value: "0x05AC:0x0269"),
                                        PeripheralMockDetail(id: "Serial", value: "CC23259W33L")
                                    ]
                                    ForEach(mockDetails) { detail in
                                        HStack(alignment: .center) {
                                            Text(detail.id)
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .foregroundColor(.secondary)
                                                .frame(width: 85, alignment: .leading)
                                            Spacer(minLength: 4)
                                            Text(detail.value)
                                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }
                            }
                            .padding(.bottom, 4)
                        }
                        
                        if isDrive {
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
                                            if !isPreview, let notification = notification {
                                                mediaKeyManager.openDrive(for: notification)
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
                                            if !isPreview, let notification = notification {
                                                isEjecting = true
                                                mediaKeyManager.ejectDrive(for: notification) { success, node in
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
                            .padding(.bottom, 16)
                            .padding(.top, 4)
                        } else if hasDetails {
                            Color.clear.frame(height: 4)
                        }
                    }
                } else {
                    EmptyView()
                }
            }
        )
        .onHoverExact { hovering in
            if !isPreview {
                self.isHovering = hovering
                let keepAliveType = notification != nil ? "peripheral_\(notification!.id)" : "peripheral"
                mediaKeyManager.keepAlive(for: keepAliveType, isHovering: hovering || isExpanded)
            }
        }
        .onChange(of: isExpanded) { _, expanded in
            if !isPreview {
                let keepAliveType = notification != nil ? "peripheral_\(notification!.id)" : "peripheral"
                mediaKeyManager.keepAlive(for: keepAliveType, isHovering: isHovering || expanded)
                
                let currentType = notification?.type ?? ""
                let currentIcon = notification?.icon ?? ""
                let currentIsDrive = currentType == "USB Drive" || currentIcon == "externaldrive" || currentType == "USB Device"
                
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
        .onChange(of: notification?.isConnected) { _, connected in
            if connected == false {
                isExpanded = false
            }
        }
        .onChange(of: notification?.timestamp) { _, _ in
            // When a new event happens for this device (like physically replugging), reset the manual mount/eject states
            if notification?.isConnected == true {
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
            fetchDriveCapacity(type: type, typeIcon: typeIcon)
        }
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            if isConnected && !isEjected && driveTotalSpace == nil && (type == "USB Drive" || typeIcon == "externaldrive" || type == "USB Device") {
                fetchDriveCapacity(type: type, typeIcon: typeIcon)
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
        .applyTheme(mediaKeyManager.overlayTheme)
    }
    
    private func fetchDriveCapacity(type: String, typeIcon: String) {
        if type == "USB Drive" || typeIcon == "externaldrive" || type == "USB Device",
           let notification = notification,
           let cap = mediaKeyManager.getDriveCapacity(for: notification) {
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
