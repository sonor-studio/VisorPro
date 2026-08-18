import SwiftUI

struct PeripheralSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("peripheralOverlayPosition") private var peripheralOverlayPosition: String = "top"
    @State private var isHistoryExpanded: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
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
                .padding(.horizontal)
                
                if mediaKeyManager.enablePeripheral {
                    VStack(alignment: .center) {
                        Text("Preview")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ZStack {
                            PreviewBackgroundView()
                            
                            HStack(spacing: -10) {
                                PeripheralOverlayView(isPreview: true, previewIsConnected: true)
                                    .scaleEffect(0.85)
                                PeripheralOverlayView(isPreview: true, previewIsConnected: false)
                                    .scaleEffect(0.85)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Overlay Triggers")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.bottom, 4)
                            .padding(.leading, 4)
                        
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "cable.connector", iconColor: .teal, title: "Device Connected", subtitle: "Show overlay when a new peripheral is plugged in") {
                                Toggle("", isOn: $mediaKeyManager.notifyOnPeripheralConnect).labelsHidden()
                            }
                        if mediaKeyManager.notifyOnPeripheralConnect {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnPeripheralConnect)
                        }
                            Divider().padding(.leading, 48)
                            CustomSettingsRow(icon: "cable.connector.slash", iconColor: .teal, title: "Device Disconnected", subtitle: "Show overlay when a peripheral is unplugged") {
                                Toggle("", isOn: $mediaKeyManager.notifyOnPeripheralDisconnect).labelsHidden()
                            }
                        if mediaKeyManager.notifyOnPeripheralDisconnect {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnPeripheralDisconnect)
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
                        
                        Text("Overlay Position")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.top, 10)
                        
                        PositionPickerGroup(selection: $peripheralOverlayPosition)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }


        }
        .navigationTitle("Peripherals")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}
