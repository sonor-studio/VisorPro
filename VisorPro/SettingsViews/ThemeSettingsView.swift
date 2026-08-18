import SwiftUI

struct ThemeSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("themeOverlayPosition") private var themeOverlayPosition: String = "top"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
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
                .padding(.horizontal)
                
                if mediaKeyManager.enableTheme {
                    VStack(alignment: .center) {
                        Text("Preview")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ZStack {
                            PreviewBackgroundView()
                            
                            HStack(spacing: -10) {
                                ThemeOverlayView(isPreview: true, previewIsDark: false)
                                    .scaleEffect(0.85)
                                ThemeOverlayView(isPreview: true, previewIsDark: true)
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
                            CustomSettingsRow(icon: "moon.fill", iconColor: .purple, title: "Dark Mode", subtitle: "Show overlay when switching to Dark Mode") {
                                Toggle("", isOn: $mediaKeyManager.notifyOnThemeDark).labelsHidden()
                            }
                        if mediaKeyManager.notifyOnThemeDark {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnThemeDark)
                        }
                            Divider().padding(.leading, 48)
                            CustomSettingsRow(icon: "sun.max.fill", iconColor: .purple, title: "Light Mode", subtitle: "Show overlay when switching to Light Mode") {
                                Toggle("", isOn: $mediaKeyManager.notifyOnThemeLight).labelsHidden()
                            }
                        if mediaKeyManager.notifyOnThemeLight {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnThemeLight)
                        }
                        }
                        .toggleStyle(.switch)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                        )
                        
                        Text("Overlay Position")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.top, 10)
                        
                        PositionPickerGroup(selection: $themeOverlayPosition)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
        }
        .navigationTitle("Theme")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}
