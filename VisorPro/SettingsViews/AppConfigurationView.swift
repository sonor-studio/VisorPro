import SwiftUI

struct AppConfigurationView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("previewBackgroundStyle") private var previewBackgroundStyle = "gradient"
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("System Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Theme Configuration")
                        .font(.headline)
                    Text("Choose the appearance of the overlay tiles.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 20) {
                        ThemeSelectionCard(title: "System", themeValue: "system", isSelected: mediaKeyManager.overlayTheme == "system") {
                            mediaKeyManager.overlayTheme = "system"
                        }
                        ThemeSelectionCard(title: "Dark", themeValue: "dark", isSelected: mediaKeyManager.overlayTheme == "dark") {
                            mediaKeyManager.overlayTheme = "dark"
                        }
                        ThemeSelectionCard(title: "Light", themeValue: "light", isSelected: mediaKeyManager.overlayTheme == "light") {
                            mediaKeyManager.overlayTheme = "light"
                        }
                    }
                    .padding(.top, 4)
                    
                    Divider().padding(.vertical, 5)
                    
                    Text("Preview Background")
                        .font(.headline)
                    Text("Show your desktop wallpaper in the preview boxes.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    WallpaperPickerView(previewBackgroundStyle: $previewBackgroundStyle)
                        .padding(.top, 4)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Notifications Limit")
                        .font(.headline)
                    Text("Choose the maximum number of overlay tiles that can be displayed at once.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("1")
                        Slider(value: Binding(
                            get: { Double(mediaKeyManager.maxSimultaneousNotifications) },
                            set: { mediaKeyManager.maxSimultaneousNotifications = Int($0) }
                        ), in: 1...5, step: 1)
                        Text("5")
                    }
                    
                    Text("Current limit: \(mediaKeyManager.maxSimultaneousNotifications)")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(10)
                
                Spacer()
            }
            .padding(30)
        }
    }
}
