import SwiftUI

struct DisplaySettingsView: View {
    @AppStorage("PremiumLicenseKey") private var savedLicenseKey = ""
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("displayOverlayPosition") private var displayOverlayPosition: String = "top"
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("displayAllowExpansion") private var displayAllowExpansion: Bool = true
    
    var body: some View {
        ModuleSettingsLayout(
            title: "Displays",
            isEnabled: $mediaKeyManager.enableDisplay,
            isPremium: true,
            preview: {
                ZStack {
                    HStack(alignment: .center, spacing: 20) {
                        DisplayOverlayView(isPreview: true, previewIsConnected: true).applyTheme(mediaKeyManager.overlayTheme)
                            .frame(height: 56, alignment: .center)
                        DisplayOverlayView(isPreview: true, previewIsConnected: false).applyTheme(mediaKeyManager.overlayTheme)
                            .frame(height: 56, alignment: .center)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(height: 56, alignment: .center)
                }
            },
            popovers: [
                ModulePopover(
                    icon: "display",
                    title: "Overlay Triggers",
                    content: AnyView(
                        Group {
                            if savedLicenseKey.isEmpty {
                                PremiumLockedView()
                            } else {
                                VStack(spacing: 0) {
                                    CustomSettingsRow(icon: "display.2", iconColor: .blue, title: "Monitor Connected", subtitle: "Show overlay when a new screen is plugged in") {
                                        HStack(spacing: 8) { 
                                            if mediaKeyManager.notifyOnDisplayConnect { 
                                                SoundPickerControl(selectedSound: $mediaKeyManager.soundOnDisplayConnect) 
                                                if mediaKeyManager.overlayColorMode == "custom" { ColorPickerControl(selectedColor: $mediaKeyManager.colorOnDisplayConnect) } 
                                            }
                                            Toggle("", isOn: $mediaKeyManager.notifyOnDisplayConnect).labelsHidden() 
                                        }
                                    }
                                    Divider().padding(.leading, 48)
                                    CustomSettingsRow(icon: "macwindow.badge.plus", iconColor: .blue, title: "Mode Change", subtitle: "Show overlay when switching between extend and mirror") {
                                        HStack(spacing: 8) { 
                                            if mediaKeyManager.notifyOnDisplayModeChange { 
                                                SoundPickerControl(selectedSound: $mediaKeyManager.soundOnDisplayModeChange) 
                                                if mediaKeyManager.overlayColorMode == "custom" { ColorPickerControl(selectedColor: $mediaKeyManager.colorOnDisplayModeChange) } 
                                            }
                                            Toggle("", isOn: $mediaKeyManager.notifyOnDisplayModeChange).labelsHidden() 
                                        }
                                    }
                                    Divider().padding(.leading, 48)
                                    CustomSettingsRow(icon: "display", iconColor: .blue, title: "Monitor Disconnected", subtitle: "Show overlay when a screen is unplugged") {
                                        HStack(spacing: 8) { 
                                            if mediaKeyManager.notifyOnDisplayDisconnect { SoundPickerControl(selectedSound: $mediaKeyManager.soundOnDisplayDisconnect) }
                                            Toggle("", isOn: $mediaKeyManager.notifyOnDisplayDisconnect).labelsHidden() 
                                        }
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
                                    PositionPickerGroup(selection: $displayOverlayPosition)
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
                                    Toggle("", isOn: $displayAllowExpansion)
                                        .labelsHidden()
                                        .toggleStyle(.switch)
                                }
                            }
                        )
                    )
                )
            ]
        )
        .navigationTitle("Displays")
    }
}
