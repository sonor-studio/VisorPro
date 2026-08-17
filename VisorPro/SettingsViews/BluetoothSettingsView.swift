import SwiftUI

struct BluetoothSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("bluetoothOverlayPosition") private var bluetoothOverlayPosition: String = "bottom"
    @State private var isHistoryExpanded: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 0) {
                    CustomSettingsRow(icon: "power", iconColor: .indigo, title: "Enable Bluetooth Module", subtitle: "When disabled, VisorPro completely ignores Bluetooth connections") {
                        Toggle("", isOn: $mediaKeyManager.enableBluetooth).labelsHidden()
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
                        
                        HStack(spacing: -10) {
                            BluetoothOverlayView(isPreview: true, previewIsConnected: true, previewDeviceName: "AirPods Pro")
                                .scaleEffect(0.85)
                            
                            BluetoothOverlayView(isPreview: true, previewIsConnected: false, previewDeviceName: "Magic Mouse")
                                .scaleEffect(0.85)
                        }
                    }
                    .frame(minHeight: 180)
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
                        CustomSettingsRow(icon: "link", iconColor: .indigo, title: "On Connect", subtitle: "Show an overlay when a Bluetooth device connects") {
                            Toggle("", isOn: $mediaKeyManager.notifyOnBluetoothConnect).labelsHidden()
                        }
                        if mediaKeyManager.notifyOnBluetoothConnect {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnBluetoothConnect)
                        }
                        Divider().padding(.leading, 40)
                        CustomSettingsRow(icon: "link.badge.plus", iconColor: .indigo, title: "On Disconnect", subtitle: "Show an overlay when a Bluetooth device disconnects") {
                            Toggle("", isOn: $mediaKeyManager.notifyOnBluetoothDisconnect).labelsHidden()
                        }
                        if mediaKeyManager.notifyOnBluetoothDisconnect {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnBluetoothDisconnect)
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
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
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
                    
                    Text("Overlay Position")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                    
                    HStack(spacing: 30) {
                        Spacer()
                        PositionPickerItem(title: "Top", isSelected: bluetoothOverlayPosition == "top") {
                            bluetoothOverlayPosition = "top"
                        }
                        PositionPickerItem(title: "Bottom", isSelected: bluetoothOverlayPosition == "bottom") {
                            bluetoothOverlayPosition = "bottom"
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .navigationTitle("Bluetooth")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}
