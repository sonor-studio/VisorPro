import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("overlayDisplayTarget") private var overlayDisplayTarget: String = "all"
    @State private var autoUpdate = true
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "wand.and.stars")
                        .font(.largeTitle)
                        .foregroundColor(.accentColor)
                        .frame(width: 40, height: 40)
                    VStack(alignment: .leading) {
                        Text("Show Setup Guide...")
                            .font(.headline)
                        Text("Revisit the introduction without changing your current settings.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Show") {}
                }
                .padding(.vertical, 4)
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
                Toggle("Automatically check for updates", isOn: $autoUpdate)
                Button("Check for Updates...") {}
            } header: {
                Text("Updates")
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
