import SwiftUI

struct PeripheralSettingsView: View {
    @AppStorage("PremiumLicenseKey") private var savedLicenseKey = ""
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("peripheralOverlayPosition") private var peripheralOverlayPosition: String = "top"
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("peripheralAllowExpansion") private var peripheralAllowExpansion: Bool = true
    @State private var isHistoryExpanded: Bool = false
    
    var body: some View {
        ModuleSettingsLayout(
            title: "Peripherals",
            isEnabled: $mediaKeyManager.enablePeripheral,
            isPremium: true,
            preview: {
                ZStack {
                    HStack(alignment: .center, spacing: 20) {
                        PeripheralOverlayView(isPreview: true, previewIsConnected: true).applyTheme(mediaKeyManager.overlayTheme)
                            .frame(height: 56, alignment: .center)
                        PeripheralOverlayView(isPreview: true, previewIsConnected: false).applyTheme(mediaKeyManager.overlayTheme)
                            .frame(height: 56, alignment: .center)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(height: 56, alignment: .center)
                }
            },
            popovers: [
                ModulePopover(
                    icon: "cable.connector",
                    title: "Overlay Triggers",
                    content: AnyView(
                        Group {
                            if savedLicenseKey.isEmpty {
                                PremiumLockedView()
                            } else {
                                VStack(spacing: 0) {
                                    CustomSettingsRow(icon: "cable.connector", iconColor: .teal, title: "Device Connected", subtitle: "Show overlay when a new peripheral is plugged in") {
                                        HStack(spacing: 8) { 
                                            if mediaKeyManager.notifyOnPeripheralConnect { 
                                                SoundPickerControl(selectedSound: $mediaKeyManager.soundOnPeripheralConnect) 
                                                if mediaKeyManager.overlayColorMode == "custom" { ColorPickerControl(selectedColor: $mediaKeyManager.colorOnPeripheralConnect) } 
                                            }
                                            Toggle("", isOn: $mediaKeyManager.notifyOnPeripheralConnect).labelsHidden() 
                                        }
                                    }
                                    Divider().padding(.leading, 48)
                                    CustomSettingsRow(icon: "cable.connector.slash", iconColor: .teal, title: "Device Disconnected", subtitle: "Show overlay when a peripheral is unplugged") {
                                        HStack(spacing: 8) { 
                                            if mediaKeyManager.notifyOnPeripheralDisconnect { SoundPickerControl(selectedSound: $mediaKeyManager.soundOnPeripheralDisconnect) }
                                            Toggle("", isOn: $mediaKeyManager.notifyOnPeripheralDisconnect).labelsHidden() 
                                        }
                                    }
                                }
                            }
                        }
                    )
                ),
                ModulePopover(
                    icon: "clock",
                    title: "Remembered Devices",
                    content: AnyView(
                        Group {
                            if savedLicenseKey.isEmpty {
                                PremiumLockedView()
                            } else {
                                let filteredHistory = mediaKeyManager.peripheralHistory.filter { device in
                                    !mediaKeyManager.accessoryBatteryHistory.contains { $0.hasPrefix(device) || device.hasPrefix($0) }
                                }
                                if !filteredHistory.isEmpty {
                                    let displayedHistory = isHistoryExpanded ? filteredHistory : Array(filteredHistory.prefix(3))
                                    VStack(spacing: 0) {
                                        ForEach(displayedHistory, id: \.self) { device in
                                            let deviceIcon = mediaKeyManager.peripheralIcons[device] ?? "cable.connector"
                                            CustomSettingsRow(
                                                icon: deviceIcon,
                                                iconColor: mediaKeyManager.peripheralBlocklist.contains(device) ? .gray : .teal,
                                                title: device,
                                                subtitle: mediaKeyManager.peripheralBlocklist.contains(device) ? "Notifications disabled" : "Notifications enabled"
                                            ) {
                                                HStack(spacing: 12) {
                                                    Toggle("", isOn: Binding(
                                                        get: { !mediaKeyManager.peripheralBlocklist.contains(device) },
                                                        set: { isOn in
                                                            if isOn {
                                                                mediaKeyManager.peripheralBlocklist.removeAll { $0 == device }
                                                            } else {
                                                                if !mediaKeyManager.peripheralBlocklist.contains(device) {
                                                                    mediaKeyManager.peripheralBlocklist.append(device)
                                                                }
                                                            }
                                                        }
                                                    )).labelsHidden()
                                                
                                                    Button(action: {
                                                        withAnimation {
                                                            mediaKeyManager.peripheralHistory.removeAll { $0 == device }
                                                            mediaKeyManager.peripheralBlocklist.removeAll { $0 == device }
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
                                            if device != displayedHistory.last || (mediaKeyManager.peripheralHistory.count > 3) {
                                                Divider().padding(.leading, 48)
                                            }
                                        }
                                    
                                        if mediaKeyManager.peripheralHistory.count > 3 {
                                            Button(action: {
                                                withAnimation { isHistoryExpanded.toggle() }
                                            }) {
                                                Text(isHistoryExpanded ? "Show Less" : "Show All (\(mediaKeyManager.peripheralHistory.count - 3) more)")
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(.teal)
                                                    .frame(maxWidth: .infinity, alignment: .center)
                                                    .padding(.vertical, 12)
                                                    .contentShape(Rectangle())
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                } else {
                                    CustomSettingsRow(icon: "info.circle", iconColor: .teal, title: "No Devices", subtitle: "No devices have been remembered yet.") {
                                        EmptyView()
                                    }
                                }
                            }
                        }
                    )
                ),
                ModulePopover(
                    icon: "pip",
                    title: "Position",
                    show: overlayPositionMode == "custom",
                    content: AnyView(
                        Group {
                            if savedLicenseKey.isEmpty {
                                PremiumLockedView()
                            } else {
                                if overlayPositionMode == "custom" {
                                    PositionPickerGroup(selection: $peripheralOverlayPosition)
                                        .padding(.vertical, 8)
                                } else {
                                    CustomSettingsRow(icon: "exclamationmark.triangle.fill", iconColor: .orange, title: "Custom Positioning Disabled", subtitle: "Enable Custom Positioning in General Settings to modify overlay placement.") {
                                        EmptyView()
                                    }
                                }
                            }
                        }
                    )
                )
            ],
            inlineControls: [
                AnyView(
                    InlineControlView(
                        icon: "arrow.up.left.and.arrow.down.right",
                        title: "Allow Expansion",
                        control: AnyView(
                            Group {
                                if savedLicenseKey.isEmpty {
                                    Image(systemName: "lock.fill").foregroundColor(.secondary)
                                } else {
                                    Toggle("", isOn: $peripheralAllowExpansion)
                                        .labelsHidden()
                                        .toggleStyle(.switch)
                                }
                            }
                        )
                    )
                )
            ]
        )
        .navigationTitle("Peripherals")
    }
}
