import SwiftUI

struct ThemeSettingsView: View {
    @AppStorage("PremiumLicenseKey") private var savedLicenseKey = ""
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("themeOverlayPosition") private var themeOverlayPosition: String = "top"
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("themeAllowInteractivity") private var themeAllowInteractivity: Bool = true
    @State private var showAppleEventsPermissionAlert: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Theme Module")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Text("Module Configuration")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                        
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "power", iconColor: .purple, title: "Enable Theme Module", subtitle: "When disabled, VisorPro will not show an overlay when system theme changes") {
                            Toggle("", isOn: $mediaKeyManager.enableTheme).labelsHidden()
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

                if mediaKeyManager.enableTheme || savedLicenseKey.isEmpty {
                
                    if mediaKeyManager.enableTheme {
                        VStack(alignment: .center) {
                            Text("Preview")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        
                            ZStack {
                                PreviewBackgroundView()
                            
                                HStack(spacing: -10) {
                                    ThemeOverlayView(isPreview: true, previewIsDark: false).applyTheme(mediaKeyManager.overlayTheme)
                                        .scaleEffect(0.85)
                                    ThemeOverlayView(isPreview: true, previewIsDark: true).applyTheme(mediaKeyManager.overlayTheme)
                                        .scaleEffect(0.85)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 20)
                    
                        Divider()
                    
                        if savedLicenseKey.isEmpty {
                            PremiumLockedView()
                        } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Overlay Triggers")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 4)
                                .padding(.leading, 4)
                        
                            VStack(spacing: 0) {
                                CustomSettingsRow(icon: "moon.fill", iconColor: .purple, title: "Dark Mode", subtitle: "Show overlay when switching to Dark Mode") {
                                    HStack(spacing: 8) { if mediaKeyManager.notifyOnThemeDark { SoundPickerControl(selectedSound: $mediaKeyManager.soundOnThemeDark) }
    Toggle("", isOn: $mediaKeyManager.notifyOnThemeDark).labelsHidden() }
                           
                                }
                                Divider().padding(.leading, 48)
                                CustomSettingsRow(icon: "sun.max.fill", iconColor: .purple, title: "Light Mode", subtitle: "Show overlay when switching to Light Mode") {
                                    HStack(spacing: 8) { if mediaKeyManager.notifyOnThemeLight { SoundPickerControl(selectedSound: $mediaKeyManager.soundOnThemeLight) }
    Toggle("", isOn: $mediaKeyManager.notifyOnThemeLight).labelsHidden() }
                           
                                }
                            }
                            .toggleStyle(.switch)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                            )
                        
                            Text("Behavior")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.top, 10)
                                .padding(.bottom, 4)
                                .padding(.leading, 4)
                        
                            VStack(spacing: 0) {
                                CustomSettingsRow(icon: "hand.tap.fill", iconColor: .purple, title: "Allow Interactivity", subtitle: "Allow tapping to toggle system theme") {
                                    Toggle("", isOn: $themeAllowInteractivity).labelsHidden()
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
                            
                                PositionPickerGroup(selection: $themeOverlayPosition)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                
                    Spacer()
            
                }
                } else {
                    DisabledModuleView(icon: "power", title: "Theme Module is Disabled", description: "Turn on the module to configure theme overlays.")
                }
}
        }
        .navigationTitle("Theme")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
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
