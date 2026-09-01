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
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("globalOverlayPosition") private var globalOverlayPosition: String = "top"
    @AppStorage("overlayMargin") private var overlayMargin: Double = 30.0
    @State private var autoUpdate = true
    
    var body: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Welcome Screen")
                            .font(.body)
                        Text("Replay the initial setup guide and greeting.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Open") {
                        UserDefaults.standard.set(false, forKey: "hasCompletedWelcome")
                        NotificationCenter.default.post(name: NSNotification.Name("ResetDashboardForced"), object: nil)
                    }
                }
            } header: {
                Text("Setup")
            }
            
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
                            LogManager.shared.log("Error in GeneralSettingsView.swift: \(error)", level: "ERROR")
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
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Overlays limit")
                                Text("Maximum number of tiles displayed at once.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            HStack {
                                Slider(value: Binding(
                                    get: { Double(mediaKeyManager.maxSimultaneousNotifications) },
                                    set: { mediaKeyManager.maxSimultaneousNotifications = Int($0) }
                                ), in: 1...5, step: 1)
                                .labelsHidden()
                                .frame(width: 220)
                                
                                Text("\(mediaKeyManager.maxSimultaneousNotifications)")
                                    .frame(width: 30, alignment: .trailing)
                            }
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Display duration")
                                Text("How long an overlay remains visible.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            HStack {
                                Slider(value: $notificationDuration, in: 1...10, step: 1)
                                .labelsHidden()
                                .frame(width: 220)
                                
                                Text("\(Int(notificationDuration))s")
                                    .frame(width: 30, alignment: .trailing)
                            }
                        }
                    }
                }
            } header: {
                Text("Overlays")
            }
            
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Swipe to dismiss")
                            .font(.body)
                        Text("Swipe an active overlay tile towards the nearest screen edge to quickly dismiss it.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $enableSwipeToDismiss).labelsHidden()
                }
            } header: {
                Text("Gestures")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Overlay Position Mode", selection: $overlayPositionMode) {
                        Text("Custom (Individual per module)").tag("custom")
                        Text("Fixed (Same for all modules)").tag("fixed")
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    if overlayPositionMode == "fixed" {
                        Divider().padding(.vertical, 8)
                        Text("Global Position")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        PositionPickerGroup(selection: $globalOverlayPosition)
                    }
                    Divider().padding(.vertical, 8)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Screen Edge Margin")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Distance from the edges of the screen")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            HStack {
                                Slider(value: $overlayMargin, in: 0...150, step: 5)
                                    .labelsHidden()
                                    .frame(width: 320)
                                
                                Text("\(Int(overlayMargin)) px")
                                    .frame(width: 50, alignment: .trailing)
                            }
                        }
                        VStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                    .frame(width: 180, height: 110)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                                
                                // Top-centered pill
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.8))
                                    .frame(width: 40, height: 10)
                                    .offset(y: -55 + 5 + (overlayMargin * 0.1))
                                    
                                // Bottom-centered pill
                                Capsule()
                                    .fill(Color.secondary.opacity(0.5))
                                    .frame(width: 40, height: 10)
                                    .offset(y: 55 - 5 - (overlayMargin * 0.1))
                                    
                                // Left pill
                                Capsule()
                                    .fill(Color.secondary.opacity(0.5))
                                    .frame(width: 10, height: 40)
                                    .offset(x: -90 + 5 + (overlayMargin * 0.1))
                                    
                                // Right pill
                                Capsule()
                                    .fill(Color.secondary.opacity(0.5))
                                    .frame(width: 10, height: 40)
                                    .offset(x: 90 - 5 - (overlayMargin * 0.1))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)

                    }

                }
            } header: {
                Text("Overlay Position")
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
