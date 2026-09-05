import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("overlayDisplayTarget") private var overlayDisplayTarget: String = "all"
    @AppStorage("previewBackgroundStyle") private var previewBackgroundStyle = "gradient"
    @AppStorage("enableSwipeToDismiss") private var enableSwipeToDismiss = true
    @AppStorage("enableCloseButton") private var enableCloseButton = false
    @AppStorage("reverseSwipeDirection") private var reverseSwipeDirection = false
    @AppStorage("notificationDuration") private var notificationDuration = 3.0
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("globalOverlayPosition") private var globalOverlayPosition: String = "top"
    @AppStorage("overlayMargin") private var overlayMargin: Double = 30.0
    @State private var autoUpdate = true
    @AppStorage("PremiumLicenseKey") private var savedLicenseKey = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // MARK: - Setup
                VStack(alignment: .leading, spacing: 12) {
                    Text("Setup")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                    
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Welcome Screen")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("Replay the initial setup guide and greeting.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Open") {
                                UserDefaults.standard.set(false, forKey: "hasCompletedWelcome")
                                NotificationCenter.default.post(name: NSNotification.Name("ResetDashboardForced"), object: nil)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    }
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                
                // MARK: - Startup
                VStack(alignment: .leading, spacing: 12) {
                    Text("Startup")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                    
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Launch at login")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("Automatically start VisorPro when you log in to your Mac.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $launchAtLogin).labelsHidden()
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
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        
                        Divider().padding(.leading, 12)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Show menu bar icon")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("If hidden, you can always reopen the dashboard by clicking the app icon again.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $showMenuBarIcon).labelsHidden()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
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
                
                // MARK: - Displays
                VStack(alignment: .leading, spacing: 12) {
                    Text("Displays")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                    
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Show overlays on")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("Choose which display the overlay tiles appear on.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Picker("", selection: $overlayDisplayTarget) {
                                Text("All screens").tag("all")
                                Text("Main screen").tag("main")
                                ForEach(NSScreen.screens.filter { $0.displayID != nil }, id: \.displayID!) { screen in
                                    Text(screen.localizedName).tag("screen_\(screen.displayID!)")
                                }
                            }
                            .labelsHidden()
                            .frame(width: 180)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    }
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                
                // MARK: - Theme Configuration
                VStack(alignment: .leading, spacing: 12) {
                    Text("Theme Configuration")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                    
                    VStack(spacing: 0) {
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
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    }
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                
                // MARK: - Preview Background
                VStack(alignment: .leading, spacing: 12) {
                    Text("Preview Background")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                    
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 10) {
                            WallpaperPickerView(previewBackgroundStyle: $previewBackgroundStyle)
                                .padding(.top, 4)
                                
                            Text("Show your desktop wallpaper in the preview boxes.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    }
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                
                // MARK: - Overlays
                VStack(alignment: .leading, spacing: 12) {
                    Text("Overlays")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                    
                    VStack(spacing: 0) {
                        // Overlays limit
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text("Overlays limit")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.primary)
                                    if savedLicenseKey.isEmpty {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.seal.fill")
                                            Text("Premium")
                                                .fontWeight(.bold)
                                        }
                                        .font(.system(size: 10))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green)
                                        .cornerRadius(4)
                                    }
                                }
                                Text("Maximum number of tiles displayed at once.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            HStack {
                                Slider(value: Binding(
                                    get: { Double(mediaKeyManager.maxSimultaneousNotifications) },
                                    set: { if !savedLicenseKey.isEmpty { mediaKeyManager.maxSimultaneousNotifications = Int($0) } }
                                ), in: 1...5, step: 1)
                                .disabled(savedLicenseKey.isEmpty)
                                .labelsHidden()
                                .frame(width: 220)
                                
                                Text("\(mediaKeyManager.maxSimultaneousNotifications)")
                                    .frame(width: 30, alignment: .trailing)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        
                        Divider().padding(.leading, 12)
                        
                        // Display duration
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Display duration")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("How long an overlay remains visible.")
                                    .font(.system(size: 11))
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
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    }
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                
                // MARK: - Dismissal & Interaction
                VStack(alignment: .leading, spacing: 12) {
                    Text("Dismissal & Interaction")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                    
                    VStack(spacing: 0) {
                        // Swipe to dismiss
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Swipe to dismiss")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("Swipe an active overlay tile towards the nearest screen edge to quickly dismiss it.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $enableSwipeToDismiss).labelsHidden()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        
                        if enableSwipeToDismiss {
                            Divider().padding(.leading, 12)
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Invert swipe direction")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text("Useful if you use third-party apps that reverse trackpad scrolling.")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: $reverseSwipeDirection).labelsHidden()
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .padding(.leading, 20)
                        }
                        
                        Divider().padding(.leading, 12)
                        
                        // Show close button
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Show close button")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("Displays an 'X' button in the top-left corner to quickly dismiss the overlay.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $enableCloseButton).labelsHidden()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
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
                
                // MARK: - Overlay Position
                VStack(alignment: .leading, spacing: 12) {
                    Text("Overlay Position")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                    
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Overlay Position Mode")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text("Use a single position for all modules or configure each individually.")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Picker("", selection: $overlayPositionMode) {
                                    Text("Custom (Individual per module)").tag("custom")
                                    Text("Fixed (Same for all modules)").tag("fixed")
                                }
                                .labelsHidden()
                                .pickerStyle(MenuPickerStyle())
                            }
                            
                            if overlayPositionMode == "fixed" {
                                Divider().padding(.vertical, 8)
                                Text("Global Position")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                PositionPickerGroup(selection: $globalOverlayPosition)
                            }
                            Divider().padding(.vertical, 8)
                            
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Screen Edge Margin")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.primary)
                                        Text("Distance from the edges of the screen")
                                            .font(.system(size: 11))
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
                                        
                                        Capsule()
                                            .fill(Color.accentColor.opacity(0.8))
                                            .frame(width: 40, height: 10)
                                            .offset(y: -55 + 5 + (overlayMargin * 0.1))
                                            
                                        Capsule()
                                            .fill(Color.secondary.opacity(0.5))
                                            .frame(width: 40, height: 10)
                                            .offset(y: 55 - 5 - (overlayMargin * 0.1))
                                            
                                        Capsule()
                                            .fill(Color.secondary.opacity(0.5))
                                            .frame(width: 10, height: 40)
                                            .offset(x: -90 + 5 + (overlayMargin * 0.1))
                                            
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
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    }
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                
            }
            .padding(.vertical)
        }
        .navigationTitle("General")
        .onAppear {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
            if savedLicenseKey.isEmpty {
                mediaKeyManager.maxSimultaneousNotifications = 1
            }
        }
        .onChange(of: savedLicenseKey) { oldValue, newValue in
            if newValue.isEmpty {
                mediaKeyManager.maxSimultaneousNotifications = 1
            }
        }
    }
}
