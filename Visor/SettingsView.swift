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
        case media
        case privacy
        case theme
        case peripheral
        case settings
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
                    NavigationLink(value: SidebarItem.media) {
                        Label {
                            Text("Media")
                        } icon: {
                            SidebarIcon(systemName: "playpause.fill", color: .red)
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
                            SidebarIcon(systemName: "point.3.connected.trianglepath.dotted", color: .indigo)
                        }
                    }
                    NavigationLink(value: SidebarItem.privacy) {
                        Label {
                            Text("Privacy")
                        } icon: {
                            SidebarIcon(systemName: "hand.raised.fill", color: .blue)
                        }
                    }
                    NavigationLink(value: SidebarItem.theme) {
                        Label {
                            Text("Theme")
                        } icon: {
                            SidebarIcon(systemName: "paintpalette.fill", color: .purple)
                        }
                    }
                    NavigationLink(value: SidebarItem.peripheral) {
                        Label {
                            Text("Peripherals")
                        } icon: {
                            SidebarIcon(systemName: "cable.connector", color: .teal)
                        }
                    }
                }
                
                Section("System") {
                    NavigationLink(value: SidebarItem.settings) {
                        Label {
                            Text("Settings")
                        } icon: {
                            SidebarIcon(systemName: "slider.horizontal.3", color: .gray)
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
                    WiFiSettingsView()
                case .bluetooth:
                    BluetoothSettingsView()
                case .media:
                    MediaSettingsView()
                case .privacy:
                    PrivacySettingsView()
                case .theme:
                    ThemeSettingsView()
                case .peripheral:
                    PeripheralSettingsView()
                case .settings:
                    AppConfigurationView()
                case .none:
                    Text("Select an item")
                        .font(.title)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .onChange(of: window) { _, newWindow in
            if let w = newWindow {
                w.isOpaque = false
                w.backgroundColor = .clear
                w.styleMask.insert(.miniaturizable)
                
                // Zmień aplikację na normalną (.regular), aby miała ikonę w Docku
                // i zachowywała się jak standardowe okno (np. minimalizacja do paska)
                NSApp.setActivationPolicy(.regular)
                
                // Automatycznie wymuś aktywację aplikacji i wyciągnięcie okna na wierzch, gdy tylko się pojawi
                NSApp.activate(ignoringOtherApps: true)
                w.makeKeyAndOrderFront(nil)
                w.level = .normal
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            if let closedWindow = notification.object as? NSWindow, closedWindow == window {
                // Przywróć tryb akcesoryjny (bez Docka) po zamknięciu okna
                NSApp.setActivationPolicy(.accessory)
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

class TransparentNSView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}

struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?
    
    func makeNSView(context: Context) -> NSView {
        let view = TransparentNSView()
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
            VStack(spacing: 24) {
                VStack(spacing: 0) {
                    CustomSettingsRow(icon: "power", iconColor: .blue, title: "Enable Volume Module", subtitle: "When disabled, Visor completely ignores volume keys and macOS handles them natively") {
                        Toggle("", isOn: $mediaKeyManager.enableVolume).labelsHidden()
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
                

                
                VStack(alignment: .center) {
                    Text("Preview")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ZStack {
                        Color.clear
                            .glassEffect(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .frame(height: 180)
                        
                        VolumeOverlayView(isPreview: true)
                            .scaleEffect(0.85)
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 20)
                
                Divider()
                
                if mediaKeyManager.enableVolume {
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "speaker.wave.2.fill", iconColor: .blue, title: "Notification Sound", subtitle: "Select the sound to play when changing volume") {
                            SoundPickerControl(selectedSound: $mediaKeyManager.soundOnVolume)
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)
                }
                
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
    @State private var isAccessoryHistoryExpanded: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 0) {
                    CustomSettingsRow(icon: "power", iconColor: .green, title: "Enable Battery Module", subtitle: "When disabled, Visor completely ignores power and battery state events") {
                        Toggle("", isOn: $mediaKeyManager.enableBattery).labelsHidden()
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
                
                VStack(alignment: .center) {
                    Text("Preview")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ZStack {
                        Color.clear
                            .glassEffect(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .frame(height: 180)
                        
                        BatteryOverlayView(isWarningMode: false, isPreview: true)
                            .scaleEffect(0.85)
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
                        if mediaKeyManager.notifyOnPlug {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnPlug)
                        }
                        Divider().padding(.leading, 48)
                        CustomSettingsRow(icon: "battery.25", iconColor: .yellow, title: "Battery drops to 20%", subtitle: "Show low battery warning") {
                            Toggle("", isOn: $mediaKeyManager.notifyOn20Percent).labelsHidden()
                        }
                        if mediaKeyManager.notifyOn20Percent {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOn20Percent)
                        }
                        Divider().padding(.leading, 48)
                        CustomSettingsRow(icon: "battery.0", iconColor: .red, title: "Battery drops to 10%", subtitle: "Show critical battery warning") {
                            Toggle("", isOn: $mediaKeyManager.notifyOn10Percent).labelsHidden()
                        }
                        if mediaKeyManager.notifyOn10Percent {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOn10Percent)
                        }
                        Divider().padding(.leading, 48)
                        CustomSettingsRow(icon: "battery.100", iconColor: .green, title: "Fully charged to 100%", subtitle: "Show when reaching full charge") {
                            Toggle("", isOn: $mediaKeyManager.notifyOn100Percent).labelsHidden()
                        }
                        if mediaKeyManager.notifyOn100Percent {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOn100Percent)
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
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("Accessory Batteries")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.bottom, 4)
                        .padding(.leading, 4)
                    
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "magicmouse.fill", iconColor: .green, title: "Enable Accessory Tracking", subtitle: "Track battery levels for connected mice, keyboards, and headphones") {
                            Toggle("", isOn: $mediaKeyManager.enableAccessoryBattery).labelsHidden()
                        }
                    }
                    .toggleStyle(.switch)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
                    
                    if !mediaKeyManager.accessoryBatteryHistory.isEmpty && mediaKeyManager.enableAccessoryBattery {
                        let allGroups = groupAccessoryDevices(mediaKeyManager.accessoryBatteryHistory)
                        let displayedGroups = isAccessoryHistoryExpanded ? allGroups : Array(allGroups.prefix(3))
                        
                        Text("Remembered Devices (\(allGroups.count))")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.top, 10)
                            .padding(.leading, 4)
                        
                        VStack(spacing: 0) {
                            ForEach(displayedGroups, id: \.baseName) { group in
                                if group.components.count == 1 && group.components[0] == group.baseName {
                                    AccessoryBatteryRowView(device: group.baseName, isComponent: false)
                                } else {
                                    let allBlocked = group.components.allSatisfy { mediaKeyManager.accessoryBatteryBlocklist.contains($0) }
                                    
                                    CustomSettingsRow(
                                        icon: "earpods",
                                        iconColor: allBlocked ? .gray : .green,
                                        title: group.baseName,
                                        subtitle: allBlocked ? "Wszystkie części zablokowane" : "Urządzenie wieloczęściowe"
                                    ) {
                                        Toggle("", isOn: Binding(
                                            get: { !allBlocked },
                                            set: { isOn in
                                                for comp in group.components {
                                                    if isOn {
                                                        mediaKeyManager.accessoryBatteryBlocklist.removeAll { $0 == comp }
                                                    } else {
                                                        if !mediaKeyManager.accessoryBatteryBlocklist.contains(comp) {
                                                            mediaKeyManager.accessoryBatteryBlocklist.append(comp)
                                                        }
                                                    }
                                                }
                                            }
                                        )).labelsHidden()
                                    }
                                    
                                    ForEach(group.components, id: \.self) { comp in
                                        Divider().padding(.leading, 80)
                                        AccessoryBatteryRowView(device: comp, isComponent: true)
                                    }
                                }
                                
                                if group.baseName != displayedGroups.last?.baseName || (allGroups.count > 3) {
                                    Divider().padding(.leading, 48)
                                }
                            }
                            
                            if allGroups.count > 3 {
                                Button(action: {
                                    withAnimation { isAccessoryHistoryExpanded.toggle() }
                                }) {
                                    Text(isAccessoryHistoryExpanded ? "Show Less" : "Show All (\(mediaKeyManager.accessoryBatteryHistory.count - 3) more)")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.green)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 12)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
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
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .navigationTitle("Battery")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
    
    private func groupAccessoryDevices(_ devices: [String]) -> [(baseName: String, components: [String])] {
        var dict: [String: [String]] = [:]
        var order: [String] = []
        
        for device in devices {
            let baseName: String
            if device.hasSuffix(" (Lewa)") {
                baseName = String(device.dropLast(7))
            } else if device.hasSuffix(" (Prawa)") {
                baseName = String(device.dropLast(8))
            } else if device.hasSuffix(" (Etui)") {
                baseName = String(device.dropLast(7))
            } else {
                baseName = device
            }
            
            if dict[baseName] == nil {
                dict[baseName] = []
                order.append(baseName)
            }
            dict[baseName]?.append(device)
        }
        return order.map { baseName in
            var components = dict[baseName]!
            // Jeśli mamy zduplikowany stary wpis (sam baseName bez końcówek), a są też inne końcówki (Lewa, Prawa), usuńmy go z widoku
            if components.count > 1, let idx = components.firstIndex(of: baseName) {
                components.remove(at: idx)
            }
            return (baseName: baseName, components: components)
        }
    }
}

struct AccessoryBatteryRowView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    let device: String
    let isComponent: Bool
    
    private var titleText: String {
        if isComponent {
            if device.hasSuffix(" (Lewa)") { return "Lewa Słuchawka" }
            if device.hasSuffix(" (Prawa)") { return "Prawa Słuchawka" }
            if device.hasSuffix(" (Etui)") { return "Etui" }
        }
        return device
    }
    
    var body: some View {
        let deviceIcon = mediaKeyManager.peripheralIcons[device] ?? "bolt.batteryblock.fill"
        let percentage = mediaKeyManager.accessoryBatteryLevels[device]
        let isCharging = mediaKeyManager.accessoryBatteryCharging[device] ?? false
        let isBlocked = mediaKeyManager.accessoryBatteryBlocklist.contains(device)
        
        let subtitleText = isBlocked ? "Tracking disabled" : (percentage != nil ? "Battery: \(percentage!)% \(isCharging ? "⚡️" : "")" : "Tracking enabled")
        
        CustomSettingsRow(
            icon: deviceIcon,
            iconColor: isBlocked ? .gray : .green,
            title: titleText,
            subtitle: subtitleText
        ) {
            Toggle("", isOn: Binding(
                get: { !isBlocked },
                set: { isOn in
                    if isOn {
                        mediaKeyManager.accessoryBatteryBlocklist.removeAll { $0 == device }
                    } else {
                        if !mediaKeyManager.accessoryBatteryBlocklist.contains(device) {
                            mediaKeyManager.accessoryBatteryBlocklist.append(device)
                        }
                    }
                }
            )).labelsHidden()
        }
        .padding(.leading, isComponent ? 30 : 0)
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
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("brightnessOverlayPosition") private var brightnessOverlayPosition: String = "top"
    @AppStorage("brightnessFillCenter") private var brightnessFillCenter: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 0) {
                    CustomSettingsRow(icon: "power", iconColor: .yellow, title: "Enable Brightness Module", subtitle: "When disabled, Visor completely ignores brightness keys and macOS handles them natively") {
                        Toggle("", isOn: $mediaKeyManager.enableBrightness).labelsHidden()
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
                

                
                VStack(alignment: .center) {
                    Text("Preview")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ZStack {
                        Color.clear
                            .glassEffect(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .frame(height: 180)
                        
                        BrightnessOverlayView(isPreview: true)
                            .scaleEffect(0.85)
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 20)
                
                Divider()
                
                if mediaKeyManager.enableBrightness {
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "speaker.wave.2.fill", iconColor: .yellow, title: "Notification Sound", subtitle: "Select the sound to play when changing brightness") {
                            SoundPickerControl(selectedSound: $mediaKeyManager.soundOnBrightness)
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)
                }
                
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

struct ThemeSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("themeOverlayPosition") private var themeOverlayPosition: String = "top"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 0) {
                    CustomSettingsRow(icon: "power", iconColor: .purple, title: "Enable Theme Module", subtitle: "When disabled, Visor will not show an overlay when system theme changes") {
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
                            Color.clear
                                .glassEffect(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                .frame(height: 180)
                            
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
                            CustomSettingsRow(icon: "sun.max.fill", iconColor: .orange, title: "Light Mode", subtitle: "Show overlay when switching to Light Mode") {
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
                        
                        HStack(spacing: 30) {
                            Spacer()
                            PositionPickerItem(title: "Top", isSelected: themeOverlayPosition == "top") {
                                themeOverlayPosition = "top"
                            }
                            PositionPickerItem(title: "Bottom", isSelected: themeOverlayPosition == "bottom") {
                                themeOverlayPosition = "bottom"
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(12)
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

struct KeyboardSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("copyOverlayPosition") private var copyOverlayPosition: String = "bottom"
    @AppStorage("capsLockOverlayPosition") private var capsLockOverlayPosition: String = "bottom"
    @AppStorage("languageOverlayPosition") private var languageOverlayPosition: String = "bottom"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 0) {
                    CustomSettingsRow(icon: "power", iconColor: .orange, title: "Enable Keyboard Module", subtitle: "When disabled, Visor completely ignores Caps Lock, Clipboard, and Layout shortcuts") {
                        Toggle("", isOn: $mediaKeyManager.enableKeyboard).labelsHidden()
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
                
                if mediaKeyManager.enableKeyboard {
                    VStack(alignment: .center) {
                        Text("Preview")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ZStack {
                            Color.clear
                                .glassEffect(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                .frame(height: 180)
                            
                            HStack(spacing: -10) {
                            CopyOverlayView(isPreview: true, previewAction: "copy")
                                .scaleEffect(0.85)
                            
                            CapsLockOverlayView(isPreview: true, previewIsOn: true)
                                .scaleEffect(0.85)
                        }
                        }
                        .frame(height: 180)
                        .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 24) {
                        // Clipboard Category Card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Clipboard")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 0) {
                                CustomSettingsRow(icon: "doc.on.clipboard.fill", iconColor: .blue, title: "Notify on Copy", subtitle: "Show an overlay when you copy an item") {
                                    Toggle("", isOn: $mediaKeyManager.notifyOnCopy).labelsHidden()
                                }
                        if mediaKeyManager.notifyOnCopy {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnCopy)
                        }
                                Divider().padding(.leading, 40)
                                CustomSettingsRow(icon: "scissors", iconColor: .orange, title: "Notify on Cut", subtitle: "Show an overlay when you cut an item") {
                                    Toggle("", isOn: $mediaKeyManager.notifyOnCut).labelsHidden()
                                }
                        if mediaKeyManager.notifyOnCut {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnCut)
                        }
                                Divider().padding(.leading, 40)
                                CustomSettingsRow(icon: "list.clipboard.fill", iconColor: .green, title: "Notify on Paste", subtitle: "Show an overlay when you paste an item") {
                                    Toggle("", isOn: $mediaKeyManager.notifyOnPaste).labelsHidden()
                                }
                        if mediaKeyManager.notifyOnPaste {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnPaste)
                        }
                                
                                Divider()
                                
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Overlay Position")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 10)
                                        .padding(.horizontal)
                                    
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
                                    .padding(.bottom, 12)
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
                        
                        // Caps Lock & Language Category Card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Caps Lock & Language")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 0) {
                                CustomSettingsRow(icon: "capslock.fill", iconColor: .blue, title: "Notify on Caps Lock", subtitle: "Show an overlay when Caps Lock is toggled") {
                                    Toggle("", isOn: $mediaKeyManager.notifyOnCapsLock).labelsHidden()
                                }
                        if mediaKeyManager.notifyOnCapsLock {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnCapsLock)
                        }
                                Divider().padding(.leading, 40)
                                CustomSettingsRow(icon: "globe", iconColor: .orange, title: "Notify on Language Change", subtitle: "Show an overlay when keyboard layout changes") {
                                    Toggle("", isOn: $mediaKeyManager.notifyOnLanguageChange).labelsHidden()
                                }
                        if mediaKeyManager.notifyOnLanguageChange {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnLanguageChange)
                        }
                                
                                Divider()
                                
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Overlay Position")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 10)
                                        .padding(.horizontal)
                                    
                                    HStack(spacing: 30) {
                                        Spacer()
                                        PositionPickerItem(title: "Top", isSelected: capsLockOverlayPosition == "top") {
                                            capsLockOverlayPosition = "top"
                                            languageOverlayPosition = "top"
                                        }
                                        PositionPickerItem(title: "Bottom", isSelected: capsLockOverlayPosition == "bottom") {
                                            capsLockOverlayPosition = "bottom"
                                            languageOverlayPosition = "bottom"
                                        }
                                        Spacer()
                                    }
                                    .padding(.bottom, 12)
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
                    }
                    .padding(.horizontal)
                }
                
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
    @State private var isHistoryExpanded: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 0) {
                    CustomSettingsRow(icon: "power", iconColor: .indigo, title: "Enable Bluetooth Module", subtitle: "When disabled, Visor completely ignores Bluetooth connections") {
                        Toggle("", isOn: $mediaKeyManager.enableBluetooth).labelsHidden()
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
                
                VStack(alignment: .center) {
                    Text("Preview")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ZStack {
                        Color.clear
                            .glassEffect(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .frame(height: 180)
                        
                        HStack(spacing: -10) {
                            BluetoothOverlayView(isPreview: true, previewIsConnected: true, previewDeviceName: "AirPods Pro")
                                .scaleEffect(0.85)
                            
                            BluetoothOverlayView(isPreview: true, previewIsConnected: false, previewDeviceName: "Magic Mouse")
                                .scaleEffect(0.85)
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
                        CustomSettingsRow(icon: "link", iconColor: .blue, title: "On Connect", subtitle: "Show an overlay when a Bluetooth device connects") {
                            Toggle("", isOn: $mediaKeyManager.notifyOnBluetoothConnect).labelsHidden()
                        }
                        if mediaKeyManager.notifyOnBluetoothConnect {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnBluetoothConnect)
                        }
                        Divider().padding(.leading, 40)
                        CustomSettingsRow(icon: "link.badge.plus", iconColor: .blue, title: "On Disconnect", subtitle: "Show an overlay when a Bluetooth device disconnects") {
                            Toggle("", isOn: $mediaKeyManager.notifyOnBluetoothDisconnect).labelsHidden()
                        }
                        if mediaKeyManager.notifyOnBluetoothDisconnect {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnBluetoothDisconnect)
                        }
                    }
                    .toggleStyle(.switch)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
                    
                    if !mediaKeyManager.bluetoothHistory.isEmpty {
                        let displayedHistory = isHistoryExpanded ? mediaKeyManager.bluetoothHistory : Array(mediaKeyManager.bluetoothHistory.prefix(3))
                        
                        Text("Remembered Devices (\(mediaKeyManager.bluetoothHistory.count))")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.top, 10)
                            .padding(.bottom, 4)
                            .padding(.leading, 4)
                        
                        VStack(spacing: 0) {
                            ForEach(displayedHistory, id: \.self) { device in
                                let nameLower = device.lowercased()
                                let icon: String = {
                                    if nameLower.contains("airpods") { return "airpods" }
                                    if nameLower.contains("mouse") { return "magicmouse" }
                                    if nameLower.contains("keyboard") { return "keyboard" }
                                    if nameLower.contains("trackpad") { return "magicmouse" }
                                    if nameLower.contains("headphone") { return "headphones" }
                                    if nameLower.contains("speaker") { return "speaker.wave.2" }
                                    return "point.3.connected.trianglepath.dotted"
                                }()
                                
                                CustomSettingsRow(icon: icon, iconColor: .blue, title: device, subtitle: "Show notifications for this device") {
                                    Toggle("", isOn: Binding(
                                        get: { !mediaKeyManager.bluetoothBlocklist.contains(device) },
                                        set: { isEnabled in
                                            if isEnabled {
                                                mediaKeyManager.bluetoothBlocklist.removeAll { $0 == device }
                                            } else {
                                                if !mediaKeyManager.bluetoothBlocklist.contains(device) {
                                                    mediaKeyManager.bluetoothBlocklist.append(device)
                                                }
                                            }
                                        }
                                    )).labelsHidden()
                                }
                                if device != displayedHistory.last || (mediaKeyManager.bluetoothHistory.count > 3) {
                                    Divider().padding(.leading, 40)
                                }
                            }
                            
                            if mediaKeyManager.bluetoothHistory.count > 3 {
                                Button(action: {
                                    withAnimation(.easeInOut) {
                                        isHistoryExpanded.toggle()
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Spacer()
                                        Text(isHistoryExpanded ? "Show Less" : "Show All (\(mediaKeyManager.bluetoothHistory.count - 3) more)")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.accentColor)
                                        Image(systemName: isHistoryExpanded ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.accentColor)
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
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

struct WiFiSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("wifiOverlayPosition") private var wifiOverlayPosition: String = "top"
    @State private var isHistoryExpanded: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 0) {
                    CustomSettingsRow(icon: "power", iconColor: .cyan, title: "Enable Wi-Fi Module", subtitle: "When disabled, Visor completely ignores Wi-Fi network changes") {
                        Toggle("", isOn: $mediaKeyManager.enableWiFi).labelsHidden()
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
                
                VStack(alignment: .center) {
                    Text("Preview")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ZStack {
                        Color.clear
                            .glassEffect(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .frame(height: 180)
                        
                        HStack(spacing: -10) {
                            WiFiOverlayView(isPreview: true, previewIsConnected: true, previewSSID: "Home Network")
                                .scaleEffect(0.85)
                            
                            WiFiOverlayView(isPreview: true, previewIsConnected: false, previewSSID: "Biuro_5GHz")
                                .scaleEffect(0.85)
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
                        CustomSettingsRow(icon: "link", iconColor: .cyan, title: "On Connect", subtitle: "Show an overlay when connecting to a network") {
                            Toggle("", isOn: $mediaKeyManager.notifyOnWiFiConnect).labelsHidden()
                        }
                        if mediaKeyManager.notifyOnWiFiConnect {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnWiFiConnect)
                        }
                        Divider().padding(.leading, 40)
                        CustomSettingsRow(icon: "link.badge.plus", iconColor: .cyan, title: "On Disconnect", subtitle: "Show an overlay when disconnecting from a network") {
                            Toggle("", isOn: $mediaKeyManager.notifyOnWiFiDisconnect).labelsHidden()
                        }
                        if mediaKeyManager.notifyOnWiFiDisconnect {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnWiFiDisconnect)
                        }
                    }
                    .toggleStyle(.switch)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
                    
                    if !mediaKeyManager.wifiHistory.isEmpty {
                        let displayedHistory = isHistoryExpanded ? mediaKeyManager.wifiHistory : Array(mediaKeyManager.wifiHistory.prefix(3))
                        
                        Text("Remembered Networks (\(mediaKeyManager.wifiHistory.count))")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.top, 10)
                            .padding(.bottom, 4)
                            .padding(.leading, 4)
                        
                        VStack(spacing: 0) {
                            ForEach(displayedHistory, id: \.self) { network in
                                CustomSettingsRow(icon: "wifi", iconColor: .cyan, title: network, subtitle: "Show notifications for this network") {
                                    Toggle("", isOn: Binding(
                                        get: { !mediaKeyManager.wifiBlocklist.contains(network) },
                                        set: { isEnabled in
                                            if isEnabled {
                                                mediaKeyManager.wifiBlocklist.removeAll { $0 == network }
                                            } else {
                                                if !mediaKeyManager.wifiBlocklist.contains(network) {
                                                    mediaKeyManager.wifiBlocklist.append(network)
                                                }
                                            }
                                        }
                                    )).labelsHidden()
                                }
                                if network != displayedHistory.last || (mediaKeyManager.wifiHistory.count > 3) {
                                    Divider().padding(.leading, 40)
                                }
                            }
                            
                            if mediaKeyManager.wifiHistory.count > 3 {
                                Button(action: {
                                    withAnimation(.easeInOut) {
                                        isHistoryExpanded.toggle()
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Spacer()
                                        Text(isHistoryExpanded ? "Show Less" : "Show All (\(mediaKeyManager.wifiHistory.count - 3) more)")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.accentColor)
                                        Image(systemName: isHistoryExpanded ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.accentColor)
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
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
                    
                    Text("Overlay Position")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                    
                    HStack(spacing: 30) {
                        Spacer()
                        PositionPickerItem(title: "Top", isSelected: wifiOverlayPosition == "top") {
                            wifiOverlayPosition = "top"
                        }
                        PositionPickerItem(title: "Bottom", isSelected: wifiOverlayPosition == "bottom") {
                            wifiOverlayPosition = "bottom"
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
        .navigationTitle("Wi-Fi")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

struct MediaSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("mediaOverlayPosition") private var mediaOverlayPosition: String = "bottom"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 0) {
                    CustomSettingsRow(icon: "power", iconColor: .red, title: "Enable Multimedia Module", subtitle: "When disabled, Visor will not show playback notifications") {
                        Toggle("", isOn: $mediaKeyManager.enableMediaNotification).labelsHidden()
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
                
                VStack(alignment: .center) {
                    Text("Preview")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ZStack {
                        Color.clear
                            .glassEffect(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .frame(height: 180)
                        
                        MediaOverlayView(isPreview: true)
                            .scaleEffect(0.85)
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 20)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("Notification Events")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                        
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "music.note", iconColor: .blue, title: "Start Notification", subtitle: "Shows an overlay when a new track or media starts playing") {
                            Toggle("", isOn: $mediaKeyManager.notifyMediaStart).labelsHidden()
                        }
                        if mediaKeyManager.notifyMediaStart {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundMediaStart)
                        }
                        Divider().padding(.leading, 40)
                        CustomSettingsRow(icon: "pause.fill", iconColor: .red, title: "Pause Notification", subtitle: "Shows an overlay when you pause the current media") {
                            Toggle("", isOn: $mediaKeyManager.notifyMediaPause).labelsHidden()
                        }
                        if mediaKeyManager.notifyMediaPause {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundMediaPause)
                        }
                        Divider().padding(.leading, 40)
                        CustomSettingsRow(icon: "play.fill", iconColor: .green, title: "Resume Notification", subtitle: "Shows an overlay when you resume paused media") {
                            Toggle("", isOn: $mediaKeyManager.notifyMediaResume).labelsHidden()
                        }
                        if mediaKeyManager.notifyMediaResume {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundMediaResume)
                        }
                        Divider().padding(.leading, 40)
                        CustomSettingsRow(icon: "stop.fill", iconColor: .gray, title: "End Notification", subtitle: "Shows an overlay when the track or media ends") {
                            Toggle("", isOn: $mediaKeyManager.notifyMediaEnd).labelsHidden()
                        }
                        if mediaKeyManager.notifyMediaEnd {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundMediaEnd)
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
                
                Divider()
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("Overlay Position")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                    
                    HStack(spacing: 30) {
                        Spacer()
                        PositionPickerItem(title: "Top", isSelected: mediaOverlayPosition == "top") {
                            mediaOverlayPosition = "top"
                        }
                        PositionPickerItem(title: "Bottom", isSelected: mediaOverlayPosition == "bottom") {
                            mediaOverlayPosition = "bottom"
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
        .navigationTitle("Media")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

struct PrivacySettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("micOverlayPosition") private var micOverlayPosition: String = "top"
    @AppStorage("cameraOverlayPosition") private var cameraOverlayPosition: String = "top"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Master Enable Section
                VStack(spacing: 0) {
                    CustomSettingsRow(icon: "power", iconColor: .orange, title: "Enable Privacy Module", subtitle: "When disabled, Visor completely ignores Camera and Microphone activity") {
                        Toggle("", isOn: $mediaKeyManager.enablePrivacy).labelsHidden()
                    }
                }
                .toggleStyle(.switch)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)
                
                if mediaKeyManager.enablePrivacy {
                    
                    // Previews
                    VStack(spacing: 16) {
                        Text("Preview")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.2))
                            
                            VStack {
                                Spacer()
                                HStack(spacing: -10) {
                                    MicOverlayView(isPreview: true, previewIsActive: true)
                                        .scaleEffect(0.85)
                                    
                                    CameraOverlayView(isPreview: true, previewIsActive: true)
                                        .scaleEffect(0.85)
                                }
                                Spacer()
                            }
                        }
                        .frame(height: 180)
                    }
                    
                    VStack(alignment: .leading, spacing: 24) {
                        // Category 1: Microphone Card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Microphone")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 0) {
                                CustomSettingsRow(icon: "mic.fill", iconColor: .green, title: "Notify when Microphone is ON", subtitle: "Show an overlay when the microphone starts being used") {
                                    Toggle("", isOn: $mediaKeyManager.notifyOnMicOn).labelsHidden()
                                }
                        if mediaKeyManager.notifyOnMicOn {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnMicOn)
                        }
                                Divider().padding(.leading, 40)
                                CustomSettingsRow(icon: "mic.slash.fill", iconColor: .gray, title: "Notify when Microphone is OFF", subtitle: "Show an overlay when the microphone stops being used") {
                                    Toggle("", isOn: $mediaKeyManager.notifyOnMicOff).labelsHidden()
                                }
                        if mediaKeyManager.notifyOnMicOff {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnMicOff)
                        }
                                
                                Divider()
                                
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Overlay Position")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 10)
                                        .padding(.horizontal)
                                    
                                    HStack(spacing: 30) {
                                        Spacer()
                                        PositionPickerItem(title: "Top", isSelected: micOverlayPosition == "top") {
                                            micOverlayPosition = "top"
                                        }
                                        PositionPickerItem(title: "Bottom", isSelected: micOverlayPosition == "bottom") {
                                            micOverlayPosition = "bottom"
                                        }
                                        Spacer()
                                    }
                                    .padding(.bottom, 12)
                                }
                            }
                            .toggleStyle(.switch)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        // Category 2: Camera Card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Camera")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 0) {
                                CustomSettingsRow(icon: "video.fill", iconColor: .blue, title: "Notify when Camera is ON", subtitle: "Show an overlay when the camera starts being used") {
                                    Toggle("", isOn: $mediaKeyManager.notifyOnCameraOn).labelsHidden()
                                }
                        if mediaKeyManager.notifyOnCameraOn {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnCameraOn)
                        }
                                Divider().padding(.leading, 40)
                                CustomSettingsRow(icon: "video.slash.fill", iconColor: .gray, title: "Notify when Camera is OFF", subtitle: "Show an overlay when the camera stops being used") {
                                    Toggle("", isOn: $mediaKeyManager.notifyOnCameraOff).labelsHidden()
                                }
                        if mediaKeyManager.notifyOnCameraOff {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnCameraOff)
                        }
                                
                                Divider()
                                
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Overlay Position")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 10)
                                        .padding(.horizontal)
                                    
                                    HStack(spacing: 30) {
                                        Spacer()
                                        PositionPickerItem(title: "Top", isSelected: cameraOverlayPosition == "top") {
                                            cameraOverlayPosition = "top"
                                        }
                                        PositionPickerItem(title: "Bottom", isSelected: cameraOverlayPosition == "bottom") {
                                            cameraOverlayPosition = "bottom"
                                        }
                                        Spacer()
                                    }
                                    .padding(.bottom, 12)
                                }
                            }
                            .toggleStyle(.switch)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Privacy")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

struct PeripheralSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("peripheralOverlayPosition") private var peripheralOverlayPosition: String = "top"
    @State private var isHistoryExpanded: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 0) {
                    CustomSettingsRow(icon: "power", iconColor: .teal, title: "Enable Peripherals Module", subtitle: "When disabled, Visor will not show overlays when USB/Thunderbolt devices are plugged in") {
                        Toggle("", isOn: $mediaKeyManager.enablePeripheral).labelsHidden()
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
                
                if mediaKeyManager.enablePeripheral {
                    VStack(alignment: .center) {
                        Text("Preview")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ZStack {
                            Color.clear
                                .glassEffect(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                .frame(height: 180)
                            
                            HStack(spacing: -10) {
                                PeripheralOverlayView(isPreview: true, previewIsConnected: true)
                                    .scaleEffect(0.85)
                                PeripheralOverlayView(isPreview: true, previewIsConnected: false)
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
                            CustomSettingsRow(icon: "cable.connector", iconColor: .teal, title: "Device Connected", subtitle: "Show overlay when a new peripheral is plugged in") {
                                Toggle("", isOn: $mediaKeyManager.notifyOnPeripheralConnect).labelsHidden()
                            }
                        if mediaKeyManager.notifyOnPeripheralConnect {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnPeripheralConnect)
                        }
                            Divider().padding(.leading, 48)
                            CustomSettingsRow(icon: "cable.connector.slash", iconColor: .gray, title: "Device Disconnected", subtitle: "Show overlay when a peripheral is unplugged") {
                                Toggle("", isOn: $mediaKeyManager.notifyOnPeripheralDisconnect).labelsHidden()
                            }
                        if mediaKeyManager.notifyOnPeripheralDisconnect {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnPeripheralDisconnect)
                        }
                        }
                        .toggleStyle(.switch)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                        )
                        
                        if !mediaKeyManager.peripheralHistory.isEmpty {
                            let displayedHistory = isHistoryExpanded ? mediaKeyManager.peripheralHistory : Array(mediaKeyManager.peripheralHistory.prefix(3))
                            
                            Text("Remembered Devices (\(mediaKeyManager.peripheralHistory.count))")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.top, 10)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 0) {
                                ForEach(displayedHistory, id: \.self) { device in
                                    let deviceIcon = mediaKeyManager.peripheralIcons[device] ?? "cable.connector"
                                    CustomSettingsRow(
                                        icon: deviceIcon,
                                        iconColor: mediaKeyManager.peripheralBlocklist.contains(device) ? .gray : .teal,
                                        title: device,
                                        subtitle: mediaKeyManager.peripheralBlocklist.contains(device) ? "Notifications disabled" : "Notifications enabled"
                                    ) {
                                        Toggle("", isOn: Binding(
                                            get: { !mediaKeyManager.peripheralBlocklist.contains(device) },
                                            set: { isOn in
                                                if isOn {
                                                    mediaKeyManager.peripheralBlocklist.removeAll { $0 == device }
                                                } else {
                                                    if !mediaKeyManager.peripheralBlocklist.contains(device) {
                                                        mediaKeyManager.peripheralBlocklist.append(device)
                                                    }
                                                }
                                            }
                                        )).labelsHidden()
                                    }
                                    if device != displayedHistory.last || (mediaKeyManager.peripheralHistory.count > 3) {
                                        Divider().padding(.leading, 48)
                                    }
                                }
                                
                                if mediaKeyManager.peripheralHistory.count > 3 {
                                    Button(action: {
                                        withAnimation { isHistoryExpanded.toggle() }
                                    }) {
                                        Text(isHistoryExpanded ? "Show Less" : "Show All (\(mediaKeyManager.peripheralHistory.count - 3) more)")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.teal)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .padding(.vertical, 12)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(PlainButtonStyle())
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
                        
                        Text("Overlay Position")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.top, 10)
                        
                        HStack(spacing: 30) {
                            Spacer()
                            PositionPickerItem(title: "Top", isSelected: peripheralOverlayPosition == "top") {
                                peripheralOverlayPosition = "top"
                            }
                            PositionPickerItem(title: "Bottom", isSelected: peripheralOverlayPosition == "bottom") {
                                peripheralOverlayPosition = "bottom"
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }


        }
        .navigationTitle("Peripherals")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

struct SoundPickerControl: View {
    @Binding var selectedSound: String
    let availableSounds = ["None", "Default", "Power Chime", "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"]
    
    var body: some View {
        Picker("", selection: $selectedSound) {
            ForEach(availableSounds, id: \.self) { sound in
                Text(sound == "None" ? "None" : sound).tag(sound)
            }
        }
        .pickerStyle(MenuPickerStyle())
        .toggleStyle(DefaultToggleStyle())
        .labelsHidden()
        .frame(width: 130)
        .onChange(of: selectedSound) { _, newValue in
            MediaKeyManager.shared.playNotificationSound(named: newValue)
        }
    }
}

struct SoundPickerRow: View {
    @Binding var selectedSound: String
    
    var body: some View {
        HStack {
            Spacer()
            Image(systemName: "speaker.wave.2.fill")
                .foregroundColor(.secondary)
                .font(.system(size: 12))
            SoundPickerControl(selectedSound: $selectedSound)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .padding(.top, -6)
    }
}


struct AppConfigurationView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    
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
                    
                    Picker("", selection: $mediaKeyManager.overlayTheme) {
                        Text("Dark (Default)").tag("dark")
                        Text("Light").tag("light")
                        Text("System").tag("system")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(maxWidth: 300)
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

