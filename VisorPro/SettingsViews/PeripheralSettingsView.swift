import SwiftUI

struct PeripheralSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("peripheralOverlayPosition") private var peripheralOverlayPosition: String = "top"
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("peripheralAllowExpansion") private var peripheralAllowExpansion: Bool = true
    @State private var isHistoryExpanded: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Peripherals Module")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Text("Module Configuration")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                        
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "power", iconColor: .teal, title: "Enable Peripherals Module", subtitle: "When disabled, VisorPro will not show overlays when USB/Thunderbolt devices are plugged in") {
                            Toggle("", isOn: $mediaKeyManager.enablePeripheral).labelsHidden()
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
                .padding(.horizontal)

                if mediaKeyManager.enablePeripheral {
                
                    if mediaKeyManager.enablePeripheral {
                        VStack(alignment: .center) {
                            Text("Preview")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        
                            ZStack {
                                PreviewBackgroundView()
                            
                                HStack(spacing: 20) {
                                    PeripheralOverlayView(isPreview: true, previewIsConnected: true).applyTheme(mediaKeyManager.overlayTheme)
                                        .scaleEffect(0.85)
                                    PeripheralOverlayView(isPreview: true, previewIsConnected: false).applyTheme(mediaKeyManager.overlayTheme)
                                        .scaleEffect(0.85)
                                }
                            }
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
                                CustomSettingsRow(icon: "cable.connector", iconColor: .teal, title: "Device Connected", subtitle: "Show overlay when a new peripheral is plugged in") {
                                    HStack(spacing: 8) { if mediaKeyManager.notifyOnPeripheralConnect { SoundPickerControl(selectedSound: $mediaKeyManager.soundOnPeripheralConnect) }
    Toggle("", isOn: $mediaKeyManager.notifyOnPeripheralConnect).labelsHidden() }
                           
                                }
                                Divider().padding(.leading, 48)
                                CustomSettingsRow(icon: "cable.connector.slash", iconColor: .teal, title: "Device Disconnected", subtitle: "Show overlay when a peripheral is unplugged") {
                                    HStack(spacing: 8) { if mediaKeyManager.notifyOnPeripheralDisconnect { SoundPickerControl(selectedSound: $mediaKeyManager.soundOnPeripheralDisconnect) }
    Toggle("", isOn: $mediaKeyManager.notifyOnPeripheralDisconnect).labelsHidden() }
                           
                                }
                            }
                            .toggleStyle(.switch)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                            )
                        
                            if !mediaKeyManager.peripheralHistory.isEmpty {
                                let displayedHistory = isHistoryExpanded ? mediaKeyManager.peripheralHistory : Array(mediaKeyManager.peripheralHistory.prefix(3))
                            
                                Text("Remembered Devices (\(mediaKeyManager.peripheralHistory.count))")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 10)
                                    .padding(.leading, 4)
                            
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
                                CustomSettingsRow(icon: "arrow.up.left.and.arrow.down.right", iconColor: .teal, title: "Allow Expansion", subtitle: "Allow overlay to expand and show peripheral details") {
                                    Toggle("", isOn: $peripheralAllowExpansion).labelsHidden()
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
                            
                                PositionPickerGroup(selection: $peripheralOverlayPosition)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                
                    Spacer()
            
                } else {
                    DisabledModuleView(icon: "power", title: "Peripherals Module is Disabled", description: "Turn on the module to configure USB and Thunderbolt overlays.")
                }
}


        }
        .navigationTitle("Peripherals")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}
