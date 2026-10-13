import SwiftUI
import CoreLocation

struct WiFiSettingsView: View {
    @AppStorage("PremiumLicenseKey") private var savedLicenseKey = ""
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("wifiOverlayPosition") private var wifiOverlayPosition: String = "top"
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("wifiAllowExpansion") private var wifiAllowExpansion: Bool = true
    @AppStorage("wifiShowSpeedTest") private var wifiShowSpeedTest: Bool = true
    @AppStorage("wifiShowDetails") private var wifiShowDetails: Bool = true
    @State private var isHistoryExpanded: Bool = false
    @State private var showLocationPermissionAlert: Bool = false
    
    var body: some View {
        ModuleSettingsLayout(
            title: "Wi-Fi",
            isEnabled: Binding(
                get: { mediaKeyManager.enableWiFi },
                set: { newValue in
                    if newValue {
                        if PermissionHelper.hasLocationPermission() {
                            mediaKeyManager.enableWiFi = true
                        } else if PermissionHelper.isLocationNotDetermined() {
                            PermissionHelper.requestLocationPermission()
                        } else {
                            showLocationPermissionAlert = true
                        }
                    } else {
                        mediaKeyManager.enableWiFi = false
                    }
                }
            ),
            isPremium: true,
            preview: {
                HStack(alignment: .center, spacing: 20) {
                    WiFiOverlayView(isPreview: true, previewIsConnected: true, previewSSID: "Home Network").applyTheme(mediaKeyManager.overlayTheme)
                        .frame(height: 56, alignment: .center)
                
                    WiFiOverlayView(isPreview: true, previewIsConnected: false, previewSSID: "Biuro_5GHz").applyTheme(mediaKeyManager.overlayTheme)
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
                                    CustomSettingsRow(icon: "link", iconColor: .cyan, title: "On Connect", subtitle: "Show an overlay when connecting to a network") {
                                        HStack(spacing: 8) { 
                                            if mediaKeyManager.notifyOnWiFiConnect { 
                                                SoundPickerControl(selectedSound: $mediaKeyManager.soundOnWiFiConnect) 
                                                if mediaKeyManager.overlayColorMode == "custom" { 
                                                    ColorPickerControl(selectedColor: $mediaKeyManager.colorOnWiFiConnect) 
                                                } 
                                            }
                                            Toggle("", isOn: $mediaKeyManager.notifyOnWiFiConnect).labelsHidden() 
                                        }
                                    }
                                    Divider().padding(.leading, 40)
                                    CustomSettingsRow(icon: "link.badge.plus", iconColor: .cyan, title: "On Disconnect", subtitle: "Show an overlay when disconnecting from a network") {
                                        HStack(spacing: 8) { 
                                            if mediaKeyManager.notifyOnWiFiDisconnect { 
                                                SoundPickerControl(selectedSound: $mediaKeyManager.soundOnWiFiDisconnect) 
                                            }
                                            Toggle("", isOn: $mediaKeyManager.notifyOnWiFiDisconnect).labelsHidden() 
                                        }
                                    }
                                }
                            }
                        }
                    )
                ),
                ModulePopover(
                    icon: "clock.arrow.circlepath",
                    title: "Remembered Networks",
                    content: AnyView(
                        Group {
                            if savedLicenseKey.isEmpty {
                                PremiumLockedView()
                            } else {
                                VStack(spacing: 0) {
                                    if mediaKeyManager.wifiHistory.isEmpty {
                                        Text("No networks remembered yet")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .padding()
                                    } else {
                                        let displayedHistory = isHistoryExpanded ? mediaKeyManager.wifiHistory : Array(mediaKeyManager.wifiHistory.prefix(3))
                                        
                                        ForEach(displayedHistory, id: \.self) { network in
                                            CustomSettingsRow(icon: "wifi", iconColor: .cyan, title: network, subtitle: "Show notifications for this network") {
                                                HStack(spacing: 12) {
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
                                                
                                                    Button(action: {
                                                        withAnimation {
                                                            mediaKeyManager.wifiHistory.removeAll { $0 == network }
                                                            mediaKeyManager.wifiBlocklist.removeAll { $0 == network }
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
                                }
                            }
                        }
                    )
                ),
                ModulePopover(
                    icon: "slider.horizontal.3",
                    title: "Expanded View",
                    content: AnyView(
                        Group {
                            if savedLicenseKey.isEmpty {
                                PremiumLockedView()
                            } else {
                                VStack(spacing: 0) {
                                    CustomSettingsRow(icon: "network", iconColor: .cyan, title: "Speed Test", subtitle: "Show network speed test in expanded view") {
                                        Toggle("", isOn: $wifiShowSpeedTest).labelsHidden()
                                            .disabled(wifiShowSpeedTest && !wifiShowDetails)
                                    }
                                    
                                    Divider().padding(.leading, 40)
                                    
                                    CustomSettingsRow(icon: "info.circle", iconColor: .cyan, title: "Network Details", subtitle: "Show IP address, Tx rate and other details") {
                                        Toggle("", isOn: $wifiShowDetails).labelsHidden()
                                            .disabled(wifiShowDetails && !wifiShowSpeedTest)
                                    }
                                    
                                    Divider().padding(.leading, 40)
                                    
                                    CustomSettingsRow(icon: "arrow.up.left.and.arrow.down.right", iconColor: .cyan, title: "Allow Expansion", subtitle: "Allow overlay to expand and show network details") {
                                        Toggle("", isOn: $wifiAllowExpansion).labelsHidden()
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
                                        PositionPickerGroup(selection: $wifiOverlayPosition)
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
            ]
        )
        .navigationTitle("Wi-Fi")
        .alert(isPresented: $showLocationPermissionAlert) {
            Alert(
                title: Text("Location Access Required"),
                message: Text("To read the Wi-Fi network name, VisorPro needs location access. Please enable it in System Settings > Privacy & Security > Location Services."),
                primaryButton: .default(Text("Open Settings")) {
                    PermissionHelper.openPrivacySettings(for: "Location")
                },
                secondaryButton: .cancel()
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LocationAuthorizationChanged"))) { _ in
            if mediaKeyManager.enableWiFi && !PermissionHelper.hasLocationPermission() && !PermissionHelper.isLocationNotDetermined() {
                DispatchQueue.main.async {
                    mediaKeyManager.enableWiFi = true
                    DispatchQueue.main.async {
                        mediaKeyManager.enableWiFi = false
                    }
                }
                showLocationPermissionAlert = true
            }
        }
    }
}
