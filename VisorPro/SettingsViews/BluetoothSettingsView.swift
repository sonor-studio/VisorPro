import SwiftUI

struct BluetoothSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("bluetoothOverlayPosition") private var bluetoothOverlayPosition: String = "top"
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("bluetoothAllowExpansion") private var bluetoothAllowExpansion: Bool = true
    @State private var isHistoryExpanded: Bool = false
    @State private var showBluetoothPermissionAlert: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 0) {
                    CustomSettingsRow(icon: "power", iconColor: .indigo, title: "Enable Bluetooth Module", subtitle: "When disabled, VisorPro completely ignores Bluetooth connections") {
                        Toggle("", isOn: Binding(
                            get: { mediaKeyManager.enableBluetooth },
                            set: { newValue in
                                if newValue {
                                    if PermissionHelper.checkBluetoothPermission() {
                                        mediaKeyManager.enableBluetooth = true
                                    } else {
                                        mediaKeyManager.enableBluetooth = false
                                        showBluetoothPermissionAlert = true
                                    }
                                } else {
                                    mediaKeyManager.enableBluetooth = false
                                }
                            }
                        )).labelsHidden()
                    }
                }
                .toggleStyle(.switch)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal)
                
                VStack(alignment: .center) {
                    Text("Preview")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ZStack {
                        PreviewBackgroundView()
                        
                        HStack(spacing: 20) {
                            BluetoothOverlayView(isPreview: true, previewIsConnected: true, previewDeviceName: "AirPods Pro").applyTheme(mediaKeyManager.overlayTheme)
                                .scaleEffect(0.85)
                            
                            BluetoothOverlayView(isPreview: true, previewIsConnected: false, previewDeviceName: "Magic Mouse").applyTheme(mediaKeyManager.overlayTheme)
                                .scaleEffect(0.85)
                        }
                    }
                    .frame(minHeight: 180)
                    .padding(.horizontal)
                }
                .padding(.top, 20)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Overlay Triggers")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                        .padding(.leading, 4)
                    
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "link", iconColor: .indigo, title: "On Connect", subtitle: "Show an overlay when a Bluetooth device connects") {
                            HStack(spacing: 8) { if mediaKeyManager.notifyOnBluetoothConnect { SoundPickerControl(selectedSound: $mediaKeyManager.soundOnBluetoothConnect) }
Toggle("", isOn: $mediaKeyManager.notifyOnBluetoothConnect).labelsHidden() }
                       
                            }
                        Divider().padding(.leading, 40)
                        CustomSettingsRow(icon: "link.badge.plus", iconColor: .indigo, title: "On Disconnect", subtitle: "Show an overlay when a Bluetooth device disconnects") {
                            HStack(spacing: 8) { if mediaKeyManager.notifyOnBluetoothDisconnect { SoundPickerControl(selectedSound: $mediaKeyManager.soundOnBluetoothDisconnect) }
Toggle("", isOn: $mediaKeyManager.notifyOnBluetoothDisconnect).labelsHidden() }
                       
                            }
                    }
                    .toggleStyle(.switch)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
                    
                    if !mediaKeyManager.bluetoothHistory.isEmpty {
                        let displayedHistory = isHistoryExpanded ? mediaKeyManager.bluetoothHistory : Array(mediaKeyManager.bluetoothHistory.prefix(3))
                        
                        Text("Remembered Devices (\(mediaKeyManager.bluetoothHistory.count))")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.top, 10)
                            .padding(.bottom, 4)
                            .padding(.leading, 4)
                        
                        VStack(spacing: 0) {
                            ForEach(displayedHistory, id: \.self) { device in
                                let nameLower = device.lowercased()
                                let icon: String = {
                                    if nameLower.contains("airpods") { return "airpods" }
                                    if nameLower.contains("mouse") { return "magicmouse" }
                                    if nameLower.contains("keyboard") { return "keyboard" }
                                    if nameLower.contains("trackpad") { return "magicmouse" }
                                    if nameLower.contains("headphone") { return "headphones" }
                                    if nameLower.contains("speaker") { return "speaker.wave.2" }
                                    return "point.3.connected.trianglepath.dotted"
                                }()
                                
                                CustomSettingsRow(icon: icon, iconColor: .indigo, title: device, subtitle: "Show notifications for this device") {
                                    HStack(spacing: 12) {
                                        Toggle("", isOn: Binding(
                                            get: { !mediaKeyManager.bluetoothBlocklist.contains(device) },
                                            set: { isEnabled in
                                                if isEnabled {
                                                    mediaKeyManager.bluetoothBlocklist.removeAll { $0 == device }
                                                } else {
                                                    if !mediaKeyManager.bluetoothBlocklist.contains(device) {
                                                        mediaKeyManager.bluetoothBlocklist.append(device)
                                                    }
                                                }
                                            }
                                        )).labelsHidden()
                                        
                                        Button(action: {
                                            withAnimation {
                                                mediaKeyManager.bluetoothHistory.removeAll { $0 == device }
                                                mediaKeyManager.bluetoothBlocklist.removeAll { $0 == device }
                                            }
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red.opacity(0.7))
                                                .font(.system(size: 14))
                                        }
                                        .buttonStyle(.plain)
                                        .onHover { hovering in
                                            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                        }
                                    }
                                }
                                if device != displayedHistory.last || (mediaKeyManager.bluetoothHistory.count > 3) {
                                    Divider().padding(.leading, 40)
                                }
                            }
                            
                            if mediaKeyManager.bluetoothHistory.count > 3 {
                                Button(action: {
                                    withAnimation(.easeInOut) {
                                        isHistoryExpanded.toggle()
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Spacer()
                                        Text(isHistoryExpanded ? "Show Less" : "Show All (\(mediaKeyManager.bluetoothHistory.count - 3) more)")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.accentColor)
                                        Image(systemName: isHistoryExpanded ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.accentColor)
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .toggleStyle(.switch)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    Text("Behavior")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                        .padding(.leading, 4)
                    
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "arrow.up.left.and.arrow.down.right", iconColor: .indigo, title: "Allow Expansion", subtitle: "Allow overlay to expand and show device details") {
                            Toggle("", isOn: $bluetoothAllowExpansion).labelsHidden()
                        }
                    }
                    .toggleStyle(.switch)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
                    
                    Group {
                        if overlayPositionMode == "custom" {
                        Text("Overlay Position")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.top, 10)
                        
                        PositionPickerGroup(selection: $bluetoothOverlayPosition)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .navigationTitle("Bluetooth")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .alert(isPresented: $showBluetoothPermissionAlert) {
            Alert(
                title: Text("Bluetooth Access Required"),
                message: Text("To monitor Bluetooth devices, VisorPro needs Bluetooth access. Please enable it in System Settings > Privacy & Security > Bluetooth."),
                primaryButton: .default(Text("Open Settings")) {
                    PermissionHelper.openPrivacySettings(for: "Bluetooth")
                },
                secondaryButton: .cancel()
            )
        }
    }
}
