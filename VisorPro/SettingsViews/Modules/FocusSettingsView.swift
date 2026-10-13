import SwiftUI
import TelemetryClient

struct FocusSettingsView: View {
    @AppStorage("PremiumLicenseKey") private var savedLicenseKey = ""
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("focusOverlayPosition") private var focusOverlayPosition: String = "top"
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("focusDetailMode") private var focusDetailMode: Bool = false
    @AppStorage("focusAllowExpansion") private var focusAllowExpansion: Bool = true
    
    @State private var showFDAAlert: Bool = false
    
    var body: some View {
        ModuleSettingsLayout(
            title: "Focus",
            isEnabled: $mediaKeyManager.enableFocus,
            isPremium: true,
            preview: {
                HStack(alignment: .center, spacing: 20) {
                    FocusOverlayView(isPreview: true, previewIsActive: true, previewModeName: "Do Not Disturb")
                        .applyTheme(mediaKeyManager.overlayTheme)
                        .frame(height: 56, alignment: .center)
                    FocusOverlayView(isPreview: true, previewIsActive: false, previewModeName: "Do Not Disturb")
                        .applyTheme(mediaKeyManager.overlayTheme)
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
                                    CustomSettingsRow(icon: "moon.fill", iconColor: .purple, title: "Focus Mode On", subtitle: "Show overlay when Focus Mode is activated") {
                                        HStack(spacing: 8) { 
                                            if mediaKeyManager.notifyOnFocusOn { 
                                                SoundPickerControl(selectedSound: $mediaKeyManager.soundOnFocusOn) 
                                            }
                                            Toggle("", isOn: $mediaKeyManager.notifyOnFocusOn).labelsHidden() 
                                        }
                                    }
                                    Divider().padding(.leading, 48)
                                    CustomSettingsRow(icon: "moon.zzz", iconColor: .purple, title: "Focus Mode Off", subtitle: "Show overlay when Focus Mode is deactivated") {
                                        HStack(spacing: 8) { 
                                            if mediaKeyManager.notifyOnFocusOff { 
                                                SoundPickerControl(selectedSound: $mediaKeyManager.soundOnFocusOff) 
                                            }
                                            Toggle("", isOn: $mediaKeyManager.notifyOnFocusOff).labelsHidden() 
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
                                        PositionPickerGroup(selection: $focusOverlayPosition)
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
                    InlineControlView(icon: "doc.text.magnifyingglass", title: "Detailed Mode", control: 
                        Toggle("", isOn: Binding(
                            get: { focusDetailMode },
                            set: { newValue in
                                if newValue && !PermissionHelper.hasFullDiskAccess() {
                                    showFDAAlert = true
                                } else {
                                    focusDetailMode = newValue
                                    TelemetryDeck.signal("FocusDetailModeToggled", parameters: [
                                        "enabled": newValue ? "true" : "false",
                                        "focus_enabled": mediaKeyManager.enableFocus ? "true" : "false"
                                    ])
                                }
                            }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .disabled(savedLicenseKey.isEmpty)
                    )
                ),
                AnyView(
                    InlineControlView(icon: "bell.badge", title: "Reminders", control: 
                        HStack(spacing: 6) {
                            if mediaKeyManager.enableFocusReminder {
                                Picker("", selection: $mediaKeyManager.focusReminderInterval) {
                                    Text("1m").tag(1)
                                    Text("5m").tag(5)
                                    Text("15m").tag(15)
                                    Text("30m").tag(30)
                                    Text("1h").tag(60)
                                }
                                .frame(width: 60)
                                .labelsHidden()
                            }
                            Toggle("", isOn: $mediaKeyManager.enableFocusReminder)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }
                        .disabled(savedLicenseKey.isEmpty)
                    )
                ),
                AnyView(
                    InlineControlView(
                        icon: "arrow.up.left.and.arrow.down.right",
                        title: "Allow Expansion",
                        control: Toggle("", isOn: $focusAllowExpansion)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    )
                )
            ]
        )
        .navigationTitle("Focus Mode")
        .alert(isPresented: $showFDAAlert) {
            Alert(
                title: Text("Full Disk Access Required"),
                message: Text("To read the exact Focus Mode name from macOS, VisorPro needs Full Disk Access. Please enable it in System Settings > Privacy & Security > Full Disk Access, and then restart VisorPro."),
                primaryButton: .default(Text("Open Settings")) {
                    PermissionHelper.openPrivacySettings(for: "FullDisk")
                },
                secondaryButton: .cancel()
            )
        }
    }
}
