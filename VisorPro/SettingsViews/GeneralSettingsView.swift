import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("overlayDisplayTarget") private var overlayDisplayTarget: String = "all"
    @AppStorage("previewBackgroundStyle") private var previewBackgroundStyle = "gradient"
    @AppStorage("enableSwipeToDismiss") private var enableSwipeToDismiss = true
    @AppStorage("notificationDuration") private var notificationDuration = 3.0
    @State private var autoUpdate = true
    
    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                        }
                    }
                Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
            } header: {
                Text("Startup")
            }
            
            Section {
                Picker("Show overlays on", selection: $overlayDisplayTarget) {
                    Text("All screens").tag("all")
                    Text("Main screen").tag("main")
                    ForEach(NSScreen.screens.filter { $0.displayID != nil }, id: \.displayID!) { screen in
                        Text(screen.localizedName).tag("screen_\(screen.displayID!)")
                    }
                }
            } header: {
                Text("Displays")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 10) {
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
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                    
                    Text("Choose the appearance of the overlay tiles.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            } header: {
                Text("Theme Configuration")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    WallpaperPickerView(previewBackgroundStyle: $previewBackgroundStyle)
                        .padding(.top, 4)
                        
                    Text("Show your desktop wallpaper in the preview boxes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Preview Background")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Overlays limit")
                            Text("Maximum number of tiles displayed at once.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack {
                            Text("1")
                            Slider(value: Binding(
                                get: { Double(mediaKeyManager.maxSimultaneousNotifications) },
                                set: { mediaKeyManager.maxSimultaneousNotifications = Int($0) }
                            ), in: 1...5, step: 1)
                            .labelsHidden()
                            .frame(width: 140)
                            Text("5")
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Display duration")
                            Text("How long an overlay remains visible.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack {
                            Text("1s")
                            Slider(value: $notificationDuration, in: 1...10, step: 1)
                            .labelsHidden()
                            .frame(width: 140)
                            Text("10s")
                        }
                    }
                }
            } header: {
                Text("Overlays")
            }
            
            Section {
                Toggle("Swipe down on overlays to dismiss", isOn: $enableSwipeToDismiss)
            } header: {
                Text("Gestures")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("General")
        .onAppear {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }
}
