import SwiftUI

struct BluetoothSettingsView: View {
    @AppStorage("PremiumLicenseKey") private var savedLicenseKey = ""
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("bluetoothOverlayPosition") private var bluetoothOverlayPosition: String = "top"
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("bluetoothAllowExpansion") private var bluetoothAllowExpansion: Bool = true
    @State private var isHistoryExpanded: Bool = false
    @State private var showBluetoothPermissionAlert: Bool = false
    
    var body: some View {
        ModuleSettingsLayout(
            title: "Bluetooth",
            isEnabled: Binding(
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
            ),
            isPremium: true,
            preview: {
                HStack(alignment: .center, spacing: 20) {
                    BluetoothOverlayView(isPreview: true, previewIsConnected: true, previewDeviceName: "AirPods Pro").applyTheme(mediaKeyManager.overlayTheme)
                        .frame(height: 56, alignment: .center)
                
                    BluetoothOverlayView(isPreview: true, previewIsConnected: false, previewDeviceName: "Magic Mouse").applyTheme(mediaKeyManager.overlayTheme)
                        .frame(height: 56, alignment: .center)
                }
                .fixedSize(horizontal: true, vertical: false)
                .frame(height: 56, alignment: .center)
            },
            popovers: [
                ModulePopover(
                    icon: "bell.fill",
                    title: "Overlay Triggers",
                    content: AnyView(
                        Group {
                            if savedLicenseKey.isEmpty {
                                PremiumLockedView()
                            } else {
                                VStack(spacing: 0) {
                                    CustomSettingsRow(icon: "link", iconColor: .indigo, title: "On Connect", subtitle: "Show an overlay when a Bluetooth device connects") {
                                        HStack(spacing: 8) { 
                                            if mediaKeyManager.notifyOnBluetoothConnect { 
                                                SoundPickerControl(selectedSound: $mediaKeyManager.soundOnBluetoothConnect) 
                                                if mediaKeyManager.overlayColorMode == "custom" { 
                                                    ColorPickerControl(selectedColor: $mediaKeyManager.colorOnBluetoothConnect) 
                                                } 
                                            }
                                            Toggle("", isOn: $mediaKeyManager.notifyOnBluetoothConnect).labelsHidden() 
                                        }
                                    }
                                    Divider().padding(.leading, 40)
                                    CustomSettingsRow(icon: "link.badge.plus", iconColor: .indigo, title: "On Disconnect", subtitle: "Show an overlay when a Bluetooth device disconnects") {
                                        HStack(spacing: 8) { 
                                            if mediaKeyManager.notifyOnBluetoothDisconnect { 
                                                SoundPickerControl(selectedSound: $mediaKeyManager.soundOnBluetoothDisconnect) 
                                            }
                                            Toggle("", isOn: $mediaKeyManager.notifyOnBluetoothDisconnect).labelsHidden() 
                                        }
                                    }
                                }
                            }
                        }
                    )
                ),
                ModulePopover(
                    icon: "clock.arrow.circlepath",
                    title: "Remembered Devices",
                    content: AnyView(
                        Group {
                            if savedLicenseKey.isEmpty {
                                PremiumLockedView()
                            } else {
                                VStack(spacing: 0) {
                                    let filteredHistory = mediaKeyManager.bluetoothHistory.filter { device in
                                        !mediaKeyManager.accessoryBatteryHistory.contains { $0.hasPrefix(device) || device.hasPrefix($0) }
                                    }
                                    let reversedHistory = Array(filteredHistory.reversed())
                                    if reversedHistory.isEmpty {
                                        Text("No devices remembered yet")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .padding()
                                    } else {
                                        let displayedHistory = isHistoryExpanded ? reversedHistory : Array(reversedHistory.prefix(3))
                                        
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
                                            if device != displayedHistory.last || (reversedHistory.count > 3) {
                                                Divider().padding(.leading, 40)
                                            }
                                        }
                                    
                                        if reversedHistory.count > 3 {
                                            Button(action: {
                                                withAnimation(.easeInOut) {
                                                    isHistoryExpanded.toggle()
                                                }
                                            }) {
                                                HStack(spacing: 6) {
                                                    Spacer()
                                                    Text(isHistoryExpanded ? "Show Less" : "Show All (\(reversedHistory.count - 3) more)")
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
                                }
                            }
                        }
                    )
                ),
                ModulePopover(
                    icon: "pip",
                    title: "Overlay Position",
                    show: overlayPositionMode == "custom",
                    content: AnyView(
                        Group {
                            if savedLicenseKey.isEmpty {
                                PremiumLockedView()
                            } else {
                                Group {
                                    if overlayPositionMode == "custom" {
                                        PositionPickerGroup(selection: $bluetoothOverlayPosition)
                                            .padding(.vertical, 8)
                                    } else {
                                        CustomSettingsRow(icon: "exclamationmark.triangle.fill", iconColor: .orange, title: "Custom Positioning Disabled", subtitle: "Enable Custom Positioning in General Settings to modify overlay placement.") {
                                            EmptyView()
                                        }
                                    }
                                }
                            }
                        }
                    )
                )
            ],
            inlineControls: [
                AnyView(
                    InlineControlView(icon: "arrow.up.left.and.arrow.down.right", title: "Allow Expansion", control: 
                        Toggle("", isOn: $bluetoothAllowExpansion)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .disabled(savedLicenseKey.isEmpty)
                    )
                )
            ]
        )
        .navigationTitle("Bluetooth")
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
