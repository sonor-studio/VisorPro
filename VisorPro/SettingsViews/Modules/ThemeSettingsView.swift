import SwiftUI

struct ThemeSettingsView: View {
    @AppStorage("PremiumLicenseKey") private var savedLicenseKey = ""
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("themeOverlayPosition") private var themeOverlayPosition: String = "top"
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("themeAllowInteractivity") private var themeAllowInteractivity: Bool = true
    @State private var showAppleEventsPermissionAlert: Bool = false
    
    var body: some View {
        ModuleSettingsLayout(
            title: "Theme",
            isEnabled: $mediaKeyManager.enableTheme,
            isPremium: true,
            preview: {
                HStack(alignment: .center, spacing: 20) {
                    ThemeOverlayView(isPreview: true, previewIsDark: false).applyTheme(mediaKeyManager.overlayTheme)
                        .frame(height: 56, alignment: .center)
                    ThemeOverlayView(isPreview: true, previewIsDark: true).applyTheme(mediaKeyManager.overlayTheme)
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
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "moon.fill", iconColor: .purple, title: "Dark Mode", subtitle: "Show overlay when switching to Dark Mode") {
                                HStack(spacing: 8) { 
                                    if mediaKeyManager.notifyOnThemeDark { 
                                        SoundPickerControl(selectedSound: $mediaKeyManager.soundOnThemeDark) 
                                        if mediaKeyManager.overlayColorMode == "custom" { 
                                            ColorPickerControl(selectedColor: $mediaKeyManager.colorOnThemeDark) 
                                        } 
                                    }
                                    Toggle("", isOn: $mediaKeyManager.notifyOnThemeDark).labelsHidden() 
                                }
                            }
                            Divider().padding(.leading, 48)
                            CustomSettingsRow(icon: "sun.max.fill", iconColor: .purple, title: "Light Mode", subtitle: "Show overlay when switching to Light Mode") {
                                HStack(spacing: 8) { 
                                    if mediaKeyManager.notifyOnThemeLight { 
                                        SoundPickerControl(selectedSound: $mediaKeyManager.soundOnThemeLight) 
                                        if mediaKeyManager.overlayColorMode == "custom" { 
                                            ColorPickerControl(selectedColor: $mediaKeyManager.colorOnThemeLight) 
                                        } 
                                    }
                                    Toggle("", isOn: $mediaKeyManager.notifyOnThemeLight).labelsHidden() 
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
                            if overlayPositionMode == "custom" {
                                PositionPickerGroup(selection: $themeOverlayPosition)
                                    .padding(.vertical, 8)
                            } else {
                                CustomSettingsRow(icon: "exclamationmark.triangle.fill", iconColor: .orange, title: "Custom Positioning Disabled", subtitle: "Enable Custom Positioning in General Settings to modify overlay placement.") {
                                    EmptyView()
                                }
                            }
                        }
                    )
                )
            ],
            inlineControls: [
                AnyView(
                    InlineControlView(icon: "hand.tap.fill", title: "Interactivity", control: 
                        Toggle("", isOn: $themeAllowInteractivity)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    )
                )
            ]
        )
        .navigationTitle("Theme")
        .alert(isPresented: $showAppleEventsPermissionAlert) {
            Alert(
                title: Text("Apple Events Access Required"),
                message: Text("To monitor the system theme, VisorPro needs Apple Events (Automation) access. Please enable it in System Settings > Privacy & Security > Automation."),
                primaryButton: .default(Text("Open Settings")) {
                    PermissionHelper.openPrivacySettings(for: "AppleEvents")
                },
                secondaryButton: .cancel()
            )
        }
    }
}
