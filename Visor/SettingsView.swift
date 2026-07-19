import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    enum SidebarItem: Hashable {
        case general
        case volume
        case brightness
        case battery
        case keyboard
        case wifi
        case bluetooth
    }
    
    @State private var selection: SidebarItem? = .general
    @State private var window: NSWindow?
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("App Settings") {
                    NavigationLink(value: SidebarItem.general) {
                        Label {
                            Text("General")
                        } icon: {
                            SidebarIcon(systemName: "gearshape.fill", color: .gray)
                        }
                    }
                }
                
                Section("Trackers") {
                    NavigationLink(value: SidebarItem.volume) {
                        Label {
                            Text("Volume")
                        } icon: {
                            SidebarIcon(systemName: "speaker.wave.2.fill", color: .blue)
                        }
                    }
                    NavigationLink(value: SidebarItem.brightness) {
                        Label {
                            Text("Brightness")
                        } icon: {
                            SidebarIcon(systemName: "sun.max.fill", color: .yellow)
                        }
                    }
                    NavigationLink(value: SidebarItem.battery) {
                        Label {
                            Text("Battery")
                        } icon: {
                            SidebarIcon(systemName: "battery.100", color: .green)
                        }
                    }
                    NavigationLink(value: SidebarItem.keyboard) {
                        Label {
                            Text("Keyboard")
                        } icon: {
                            SidebarIcon(systemName: "keyboard", color: .orange)
                        }
                    }
                    NavigationLink(value: SidebarItem.wifi) {
                        Label {
                            Text("Wi-Fi")
                        } icon: {
                            SidebarIcon(systemName: "wifi", color: .cyan)
                        }
                    }
                    NavigationLink(value: SidebarItem.bluetooth) {
                        Label {
                            Text("Bluetooth")
                        } icon: {
                            SidebarIcon(systemName: "bluetooth", color: .indigo)
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 200, max: 250)
            .hideSidebarToggle()
        } detail: {
            Group {
                switch selection {
                case .general:
                    GeneralSettingsView()
                case .volume:
                    VolumeSettingsView()
                case .brightness:
                    BrightnessSettingsView()
                case .battery:
                    BatterySettingsView()
                case .keyboard:
                    KeyboardSettingsView()
                case .wifi:
                    PlaceholderSettingsView(title: "Wi-Fi", icon: "wifi")
                case .bluetooth:
                    BluetoothSettingsView()
                case .none:
                    Text("Select an option")
                        .font(.title)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            // Zapewniamy całkowicie przeźroczyste tło detali, by materiał tła okna był widoczny
            .background(Color.clear)
        }
        .frame(minWidth: 700, minHeight: 500)
        .background(WindowAccessor(window: $window))
        .background(
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .behindWindow)
                Color(NSColor.windowBackgroundColor).opacity(0.25) // Pośrednia przeźroczystość
            }
            .ignoresSafeArea()
        )
        .onChange(of: window) { newWindow in
            if let w = newWindow {
                w.isOpaque = false
                w.backgroundColor = .clear
                w.styleMask.insert(.miniaturizable) // Dodany przycisk minimalizacji
            }
        }
    }
}

struct SidebarIcon: View {
    let systemName: String
    let color: Color
    
    var body: some View {
        Image(systemName: systemName)
            .resizable()
            .scaledToFit()
            .frame(width: 14, height: 14)
            .foregroundColor(.white)
            .padding(4)
            .background(color)
            .cornerRadius(6)
    }
}

extension View {
    @ViewBuilder
    func hideSidebarToggle() -> some View {
        if #available(macOS 14.0, *) {
            self.toolbar(removing: .sidebarToggle)
        } else {
            self
        }
    }
}

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
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
                    .onChange(of: launchAtLogin) { newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("Failed to change launch at login status: \(error)")
                        }
                    }
                Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
            } header: {
                Text("Startup")
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

struct PlaceholderSettingsView: View {
    let title: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("\(title) Settings")
                .font(.title)
                .foregroundColor(.secondary)
            Text("Settings for \(title.lowercased()) will appear here.")
                .foregroundColor(.secondary)
        }
        .navigationTitle(title)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.window = view.window
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct VolumeSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("volumeOverlayPosition") private var volumeOverlayPosition: String = "top"
    @AppStorage("volumeFillCenter") private var volumeFillCenter: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                VStack(alignment: .center) {
                    Text("Preview")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(red: 0.10, green: 0.22, blue: 0.35).opacity(0.8),
                                Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .glassEffect(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .frame(height: 180)
                        
                        VolumeOverlayView(isPreview: true)
                            .scaleEffect(0.85) // Skalujemy lekko w dół, żeby ładnie wyglądało w oknie ustawień
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 20)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("Visual Style")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.bottom, 4)
                        .padding(.leading, 4)
                    
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "paintpalette.fill", iconColor: .purple, title: "Fill Center", subtitle: "Fills the inside of the overlay with blue color instead of just the border") {
                            Toggle("", isOn: $volumeFillCenter).labelsHidden()
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
                    
                    HStack(spacing: 30) {
                        Spacer()
                        PositionPickerItem(title: "Top", isSelected: volumeOverlayPosition == "top") {
                            volumeOverlayPosition = "top"
                        }
                        PositionPickerItem(title: "Bottom", isSelected: volumeOverlayPosition == "bottom") {
                            volumeOverlayPosition = "bottom"
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .navigationTitle("Volume")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

struct BatterySettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @Environment(\.openWindow) private var openWindow
    @AppStorage("batteryOverlayPosition") private var batteryOverlayPosition: String = "top"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                VStack(alignment: .center) {
                    Text("Preview")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(red: 0.10, green: 0.14, blue: 0.28).opacity(0.7),
                                Color(red: 0.04, green: 0.06, blue: 0.15).opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .glassEffect(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .frame(height: 180)
                        
                        BatteryOverlayView(isWarningMode: false, isPreview: true)
                            .scaleEffect(0.85) // Skalujemy lekko w dół, żeby ładnie wyglądało w oknie ustawień
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
                        CustomSettingsRow(icon: "powerplug.fill", iconColor: .green, title: "Plugged into power", subtitle: "Show when connecting the charger") {
                            Toggle("", isOn: $mediaKeyManager.notifyOnPlug).labelsHidden()
                        }
                        Divider().padding(.leading, 48)
                        CustomSettingsRow(icon: "battery.25", iconColor: .yellow, title: "Battery drops to 20%", subtitle: "Show low battery warning") {
                            Toggle("", isOn: $mediaKeyManager.notifyOn20Percent).labelsHidden()
                        }
                        Divider().padding(.leading, 48)
                        CustomSettingsRow(icon: "battery.0", iconColor: .red, title: "Battery drops to 10%", subtitle: "Show critical battery warning") {
                            Toggle("", isOn: $mediaKeyManager.notifyOn10Percent).labelsHidden()
                        }
                        Divider().padding(.leading, 48)
                        CustomSettingsRow(icon: "battery.100", iconColor: .green, title: "Fully charged to 100%", subtitle: "Show when reaching full charge") {
                            Toggle("", isOn: $mediaKeyManager.notifyOn100Percent).labelsHidden()
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
                    
                    HStack(spacing: 30) {
                        Spacer()
                        PositionPickerItem(title: "Top", isSelected: batteryOverlayPosition == "top") {
                            batteryOverlayPosition = "top"
                        }
                        PositionPickerItem(title: "Bottom", isSelected: batteryOverlayPosition == "bottom") {
                            batteryOverlayPosition = "bottom"
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Divider()
                
                Button(action: {
                    openWindow(id: "simulator")
                }) {
                    Label("Open Battery Simulator", systemImage: "macwindow.on.rectangle")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Color.accentColor)
                .padding(.top, 10)
                
                Spacer()
            }
        }
        .navigationTitle("Battery")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

struct PositionPickerItem: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.2)))
                        .frame(width: 120, height: 80)
                    
                    // Ekranik z pillsem (nakładką)
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.5))
                        .frame(width: 40, height: 8)
                        .offset(y: title == "Top" ? -25 : 25)
                }
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct CustomSettingsRow<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    let content: () -> Content
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            content()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
}

struct BrightnessSettingsView: View {
    @AppStorage("brightnessOverlayPosition") private var brightnessOverlayPosition: String = "top"
    @AppStorage("brightnessFillCenter") private var brightnessFillCenter: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                VStack(alignment: .center) {
                    Text("Preview")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.8),
                                Color(red: 0.05, green: 0.05, blue: 0.05).opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .glassEffect(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .frame(height: 180)
                        
                        BrightnessOverlayView(isPreview: true)
                            .scaleEffect(0.85) // Skalujemy lekko w dół
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 20)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("Visual Style")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.bottom, 4)
                        .padding(.leading, 4)
                    
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "paintpalette.fill", iconColor: .yellow, title: "Fill Center", subtitle: "Fills the inside of the overlay with yellow color instead of just the border") {
                            Toggle("", isOn: $brightnessFillCenter).labelsHidden()
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
                    
                    HStack(spacing: 30) {
                        Spacer()
                        PositionPickerItem(title: "Top", isSelected: brightnessOverlayPosition == "top") {
                            brightnessOverlayPosition = "top"
                        }
                        PositionPickerItem(title: "Bottom", isSelected: brightnessOverlayPosition == "bottom") {
                            brightnessOverlayPosition = "bottom"
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .navigationTitle("Brightness")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

struct KeyboardSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("copyOverlayPosition") private var copyOverlayPosition: String = "bottom"
    @AppStorage("capsLockOverlayPosition") private var capsLockOverlayPosition: String = "bottom"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                VStack(alignment: .center) {
                    Text("Preview")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(red: 0.35, green: 0.10, blue: 0.15).opacity(0.8),
                                Color(red: 0.15, green: 0.04, blue: 0.06).opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .glassEffect(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .frame(height: 180)
                        
                        GeometryReader { geo in
                            let halfWidth = geo.size.width / 2
                            let halfHeight = geo.size.height / 2
                            
                            VStack(spacing: 0) {
                                HStack(spacing: 0) {
                                    CopyOverlayView(isPreview: true, previewAction: "copy")
                                        .scaleEffect(0.6)
                                        .frame(width: halfWidth, height: halfHeight)
                                    
                                    CopyOverlayView(isPreview: true, previewAction: "cut")
                                        .scaleEffect(0.6)
                                        .frame(width: halfWidth, height: halfHeight)
                                }
                                
                                HStack(spacing: 0) {
                                    CopyOverlayView(isPreview: true, previewAction: "paste")
                                        .scaleEffect(0.6)
                                        .frame(width: halfWidth, height: halfHeight)
                                    
                                    CapsLockOverlayView(isPreview: true, previewIsOn: true)
                                        .scaleEffect(0.6)
                                        .frame(width: halfWidth, height: halfHeight)
                                }
                            }
                        }
                    }
                    .frame(height: 180)
                    .padding(.horizontal)
                }
                .padding(.top, 20)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("Notifications")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.bottom, 4)
                        .padding(.leading, 4)
                    
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "doc.on.clipboard.fill", iconColor: .blue, title: "Notify on Copy", subtitle: "Show an overlay when you copy an item") {
                            Toggle("", isOn: $mediaKeyManager.notifyOnCopy).labelsHidden()
                        }
                        Divider().padding(.leading, 40)
                        CustomSettingsRow(icon: "scissors", iconColor: .orange, title: "Notify on Cut", subtitle: "Show an overlay when you cut an item") {
                            Toggle("", isOn: $mediaKeyManager.notifyOnCut).labelsHidden()
                        }
                        Divider().padding(.leading, 40)
                        CustomSettingsRow(icon: "list.clipboard.fill", iconColor: .green, title: "Notify on Paste", subtitle: "Show an overlay when you paste an item") {
                            Toggle("", isOn: $mediaKeyManager.notifyOnPaste).labelsHidden()
                        }
                        Divider().padding(.leading, 40)
                        CustomSettingsRow(icon: "capslock.fill", iconColor: .blue, title: "Notify on Caps Lock", subtitle: "Show an overlay when Caps Lock is toggled") {
                            Toggle("", isOn: $mediaKeyManager.notifyOnCapsLock).labelsHidden()
                        }
                    }
                    .toggleStyle(.switch)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
                    
                    Text("Clipboard Overlay Position")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                    
                    HStack(spacing: 30) {
                        Spacer()
                        PositionPickerItem(title: "Top", isSelected: copyOverlayPosition == "top") {
                            copyOverlayPosition = "top"
                        }
                        PositionPickerItem(title: "Bottom", isSelected: copyOverlayPosition == "bottom") {
                            copyOverlayPosition = "bottom"
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12)
                    
                    Text("Caps Lock Overlay Position")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                    
                    HStack(spacing: 30) {
                        Spacer()
                        PositionPickerItem(title: "Top", isSelected: capsLockOverlayPosition == "top") {
                            capsLockOverlayPosition = "top"
                        }
                        PositionPickerItem(title: "Bottom", isSelected: capsLockOverlayPosition == "bottom") {
                            capsLockOverlayPosition = "bottom"
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .navigationTitle("Keyboard")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct BluetoothSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("bluetoothOverlayPosition") private var bluetoothOverlayPosition: String = "bottom"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                VStack(alignment: .center) {
                    Text("Preview")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(red: 0.15, green: 0.30, blue: 0.45).opacity(0.8),
                                Color(red: 0.05, green: 0.15, blue: 0.25).opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .glassEffect(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .frame(height: 180)
                        
                        GeometryReader { geo in
                            let halfWidth = geo.size.width / 2
                            let halfHeight = geo.size.height / 2
                            
                            VStack(spacing: 0) {
                                HStack(spacing: 0) {
                                    BluetoothOverlayView(isPreview: true, previewIsConnected: true, previewDeviceName: "AirPods Pro")
                                        .scaleEffect(0.6)
                                        .frame(width: halfWidth, height: halfHeight)
                                    
                                    BluetoothOverlayView(isPreview: true, previewIsConnected: false, previewDeviceName: "Magic Mouse")
                                        .scaleEffect(0.6)
                                        .frame(width: halfWidth, height: halfHeight)
                                }
                            }
                            .frame(maxHeight: .infinity, alignment: .center)
                        }
                    }
                    .frame(height: 180)
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
                        CustomSettingsRow(icon: "bluetooth", iconColor: .blue, title: "Bluetooth connection status", subtitle: "Show an overlay when a Bluetooth device connects or disconnects") {
                            Toggle("", isOn: $mediaKeyManager.notifyOnBluetooth).labelsHidden()
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
                    
                    HStack(spacing: 30) {
                        Spacer()
                        PositionPickerItem(title: "Top", isSelected: bluetoothOverlayPosition == "top") {
                            bluetoothOverlayPosition = "top"
                        }
                        PositionPickerItem(title: "Bottom", isSelected: bluetoothOverlayPosition == "bottom") {
                            bluetoothOverlayPosition = "bottom"
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .navigationTitle("Bluetooth")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}
