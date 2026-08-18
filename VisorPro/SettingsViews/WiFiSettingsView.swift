import SwiftUI

struct WiFiSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("wifiOverlayPosition") private var wifiOverlayPosition: String = "top"
    @State private var isHistoryExpanded: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 0) {
                    CustomSettingsRow(icon: "power", iconColor: .cyan, title: "Enable Wi-Fi Module", subtitle: "When disabled, VisorPro completely ignores Wi-Fi network changes") {
                        Toggle("", isOn: $mediaKeyManager.enableWiFi).labelsHidden()
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
                            WiFiOverlayView(isPreview: true, previewIsConnected: true, previewSSID: "Home Network")
                                .scaleEffect(0.85)
                            
                            WiFiOverlayView(isPreview: true, previewIsConnected: false, previewSSID: "Biuro_5GHz")
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
                        CustomSettingsRow(icon: "link", iconColor: .cyan, title: "On Connect", subtitle: "Show an overlay when connecting to a network") {
                            Toggle("", isOn: $mediaKeyManager.notifyOnWiFiConnect).labelsHidden()
                        }
                        if mediaKeyManager.notifyOnWiFiConnect {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnWiFiConnect)
                        }
                        Divider().padding(.leading, 40)
                        CustomSettingsRow(icon: "link.badge.plus", iconColor: .cyan, title: "On Disconnect", subtitle: "Show an overlay when disconnecting from a network") {
                            Toggle("", isOn: $mediaKeyManager.notifyOnWiFiDisconnect).labelsHidden()
                        }
                        if mediaKeyManager.notifyOnWiFiDisconnect {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnWiFiDisconnect)
                        }
                    }
                    .toggleStyle(.switch)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
                    
                    if !mediaKeyManager.wifiHistory.isEmpty {
                        let displayedHistory = isHistoryExpanded ? mediaKeyManager.wifiHistory : Array(mediaKeyManager.wifiHistory.prefix(3))
                        
                        Text("Remembered Networks (\(mediaKeyManager.wifiHistory.count))")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.top, 10)
                            .padding(.bottom, 4)
                            .padding(.leading, 4)
                        
                        VStack(spacing: 0) {
                            ForEach(displayedHistory, id: \.self) { network in
                                CustomSettingsRow(icon: "wifi", iconColor: .cyan, title: network, subtitle: "Show notifications for this network") {
                                    Toggle("", isOn: Binding(
                                        get: { !mediaKeyManager.wifiBlocklist.contains(network) },
                                        set: { isEnabled in
                                            if isEnabled {
                                                mediaKeyManager.wifiBlocklist.removeAll { $0 == network }
                                            } else {
                                                if !mediaKeyManager.wifiBlocklist.contains(network) {
                                                    mediaKeyManager.wifiBlocklist.append(network)
                                                }
                                            }
                                        }
                                    )).labelsHidden()
                                }
                                if network != displayedHistory.last || (mediaKeyManager.wifiHistory.count > 3) {
                                    Divider().padding(.leading, 40)
                                }
                            }
                            
                            if mediaKeyManager.wifiHistory.count > 3 {
                                Button(action: {
                                    withAnimation(.easeInOut) {
                                        isHistoryExpanded.toggle()
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Spacer()
                                        Text(isHistoryExpanded ? "Show Less" : "Show All (\(mediaKeyManager.wifiHistory.count - 3) more)")
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
                    
                    PositionPickerGroup(selection: $wifiOverlayPosition)
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .navigationTitle("Wi-Fi")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}
