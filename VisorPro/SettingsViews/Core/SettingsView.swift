import SwiftUI
import AppKit
import AVFoundation
import ServiceManagement

var hasShownNoticeThisSession = false

struct SettingsView: View {
    enum SidebarItem: Hashable {
        case premium
        case general
        case appearance
        case recentChanges
        case volume
        case brightness
        case keyboardBrightness
        case battery
        case keyboard
        case clipboard
        case date
        case wifi
        case bluetooth
        case media
        case privacy
        case theme
        case focus
        case peripheral
        case display
        case feedback
        case macSystem
        case trash
        case about
        case accessory(String)
    }
    
    static var pendingSelection: SidebarItem? = nil
    
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @State private var selection: SidebarItem = SettingsView.pendingSelection ?? .general
    @State private var window: NSWindow?
    @State private var keyMonitor: Any? = nil
    @AppStorage("PremiumLicenseKey") private var savedLicenseKey = ""
    @AppStorage("hasCompletedWelcome") private var hasCompletedWelcome = false
    @Environment(\.colorScheme) var colorScheme
    
    private var allVisibleItems: [SidebarItem] {
        var items: [SidebarItem] = [
            .general,
            .appearance,
            .recentChanges,
            .feedback,
            .premium,
            .volume,
            .brightness,
            .keyboardBrightness,
            .battery,
            .keyboard,
            .clipboard,
            .date,
            .media,
            .wifi,
            .bluetooth,
            .privacy,
            .theme,
            .focus,
            .peripheral,
            .display,
            .macSystem,
            .trash
        ]
        
        let accessories = Array(Set(mediaKeyManager.accessoryBatteryHistory.map { name -> String in
            if name.hasSuffix(" (Left)") { return String(name.dropLast(7)) }
            if name.hasSuffix(" (Right)") { return String(name.dropLast(8)) }
            if name.hasSuffix(" (Case)") { return String(name.dropLast(7)) }
            return name
        })).sorted()
        
        if !accessories.isEmpty && mediaKeyManager.enableBluetooth {
            for acc in accessories {
                items.append(.accessory(acc))
            }
        }
        
        items.append(.about)
        return items
    }
    
    private func selectNext() {
        let items = allVisibleItems
        guard let currentIndex = items.firstIndex(of: selection) else {
            if let first = items.first { selection = first }
            return
        }
        if currentIndex < items.count - 1 {
            selection = items[currentIndex + 1]
        }
    }
    
    private func selectPrevious() {
        let items = allVisibleItems
        guard let currentIndex = items.firstIndex(of: selection) else {
            if let first = items.first { selection = first }
            return
        }
        if currentIndex > 0 {
            selection = items[currentIndex - 1]
        }
    }
    
    var body: some View {

        HSplitView {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("App Settings")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.top, 4)
                            .padding(.bottom, 2)
                        
                        SidebarRow(title: "General", icon: "gearshape.fill", color: .gray, isSelected: selection == .general) {
                            selection = .general
                        }
                        .id(SidebarItem.general)
                        SidebarRow(title: "Design Studio", icon: "paintbrush.fill", color: .indigo, isSelected: selection == .appearance) {
                            selection = .appearance
                        }
                        .id(SidebarItem.appearance)
                        SidebarRow(title: "Changelog", icon: "clock.arrow.circlepath", color: .orange, isSelected: selection == .recentChanges) {
                            selection = .recentChanges
                        }
                        .id(SidebarItem.recentChanges)
                        SidebarRow(title: "Feedback", icon: "envelope.fill", color: .blue, isSelected: selection == .feedback) {
                            selection = .feedback
                        }
                        .id(SidebarItem.feedback)
                        SidebarRow(title: "Premium", icon: "checkmark.seal.fill", color: .green, isSelected: selection == .premium) {
                            selection = .premium
                        }
                        .id(SidebarItem.premium)
                        
                        Text("Trackers")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.top, 14)
                            .padding(.bottom, 2)
                        
                        SidebarRow(title: "Volume", icon: "speaker.wave.2.fill", color: .blue, isSelected: selection == .volume) {
                            selection = .volume
                        }
                        .id(SidebarItem.volume)
                        SidebarRow(title: "Brightness", icon: "sun.max.fill", color: .yellow, isSelected: selection == .brightness) {
                            selection = .brightness
                        }
                        .id(SidebarItem.brightness)
                        SidebarRow(title: "Keyboard Brightness", icon: "lightbulb.fill", color: .orange, isSelected: selection == .keyboardBrightness) {
                            selection = .keyboardBrightness
                        }
                        .id(SidebarItem.keyboardBrightness)
                        SidebarRow(title: "Battery", icon: "battery.100", color: .green, isSelected: selection == .battery) {
                            selection = .battery
                        }
                        .id(SidebarItem.battery)
                        SidebarRow(title: "Keyboard", icon: "keyboard", color: .orange, isSelected: selection == .keyboard) {
                            selection = .keyboard
                        }
                        .id(SidebarItem.keyboard)
                        SidebarRow(title: "Clipboard", icon: "doc.on.clipboard", color: .blue, isSelected: selection == .clipboard) {
                            selection = .clipboard
                        }
                        .id(SidebarItem.clipboard)
                        SidebarRow(title: "Date", icon: "calendar", color: OverlayColorManager.shared.parseColor("Emerald"), isSelected: selection == .date) {
                            selection = .date
                        }
                        .id(SidebarItem.date)
                        
                        // --- PREMIUM TRACKERS ---
                        SidebarRow(title: "Media", icon: "playpause.fill", color: .red, isSelected: selection == .media) {
                            selection = .media
                        }
                        .id(SidebarItem.media)
                        SidebarRow(title: "Wi-Fi", icon: "wifi", color: .cyan, isSelected: selection == .wifi) {
                            selection = .wifi
                        }
                        .id(SidebarItem.wifi)
                        SidebarRow(title: "Bluetooth", icon: "point.3.connected.trianglepath.dotted", color: .indigo, isSelected: selection == .bluetooth) {
                            selection = .bluetooth
                        }
                        .id(SidebarItem.bluetooth)
                        SidebarRow(title: "Privacy", icon: "hand.raised.fill", color: .blue, isSelected: selection == .privacy) {
                            selection = .privacy
                        }
                        .id(SidebarItem.privacy)
                        SidebarRow(title: "Theme", icon: "paintpalette.fill", color: .purple, isSelected: selection == .theme) {
                            selection = .theme
                        }
                        .id(SidebarItem.theme)
                        SidebarRow(title: "Focus Mode", icon: "moon.fill", color: .indigo, isSelected: selection == .focus) {
                            selection = .focus
                        }
                        .id(SidebarItem.focus)
                        SidebarRow(title: "Peripherals", icon: "cable.connector", color: .teal, isSelected: selection == .peripheral) {
                            selection = .peripheral
                        }
                        .id(SidebarItem.peripheral)
                        SidebarRow(title: "Displays", icon: "display.2", color: .blue, isSelected: selection == .display) {
                            selection = .display
                        }
                        .id(SidebarItem.display)
                        SidebarRow(title: "System", icon: "cpu", color: .red, isSelected: selection == .macSystem) {
                            selection = .macSystem
                        }
                        .id(SidebarItem.macSystem)
                        SidebarRow(title: "Trash", icon: "trash", color: .orange, isSelected: selection == .trash) {
                            selection = .trash
                        }
                        .id(SidebarItem.trash)
                        
                        let accessories = Array(Set(mediaKeyManager.accessoryBatteryHistory.map { name -> String in
                            if name.hasSuffix(" (Left)") { return String(name.dropLast(7)) }
                            if name.hasSuffix(" (Right)") { return String(name.dropLast(8)) }
                            if name.hasSuffix(" (Case)") { return String(name.dropLast(7)) }
                            return name
                        })).sorted()
                        
                        if !accessories.isEmpty && mediaKeyManager.enableBluetooth {
                            Text("Accessories")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.top, 14)
                                .padding(.bottom, 2)
                            
                            ForEach(accessories, id: \.self) { accessoryName in
                                let deviceIcon = mediaKeyManager.peripheralIcons[accessoryName] ?? MediaKeyManager.fallbackIcon(for: accessoryName)
                                let isBluetooth = mediaKeyManager.isBluetoothAccessory(accessoryName)
                                let activeColor: Color = isBluetooth ? .indigo : .teal
                                let isSelected: Bool = {
                                    if case .accessory(let sel) = selection { return sel == accessoryName }
                                    return false
                                }()
                                
                                SidebarRow(title: accessoryName, icon: deviceIcon, color: activeColor, isSelected: isSelected) {
                                    selection = .accessory(accessoryName)
                                }
                                .id(SidebarItem.accessory(accessoryName))
                            }
                        }
                        
                        Text("Information")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.top, 14)
                            .padding(.bottom, 2)
                        
                        SidebarRow(title: "About", icon: "info.circle.fill", color: .gray, isSelected: selection == .about) {
                            selection = .about
                        }
                        .id(SidebarItem.about)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                }
                .scrollContentBackground(.hidden)
                .onChange(of: selection) { _, newSelection in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        scrollProxy.scrollTo(newSelection, anchor: nil)
                    }
                }
            }
            .overlay(alignment: .top) {
                VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                    .background((colorScheme == .dark ? Color.black : Color.white).opacity(0.40))
                    .frame(height: 28)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
            .background(
                (colorScheme == .dark ? Color.black : Color.white).opacity(0.40)
                .ignoresSafeArea()
            )
            .frame(minWidth: 150, idealWidth: 180, maxWidth: 210)
            .hideSidebarToggle()
            
            Group {
                
                switch selection {
                case .premium:
                    PremiumSettingsView()
                case .general:
                    GeneralSettingsView()
                case .appearance:
                    AppearanceEditorView()
                case .recentChanges:
                    ChangelogSettingsView()
                case .feedback:
                    FeedbackSettingsView()
                case .about:
                    AboutSettingsView()
                    
                // FREE TRACKERS
                case .volume:
                    VolumeSettingsView()
                case .brightness:
                    BrightnessSettingsView()
                case .keyboardBrightness:
                    KeyboardBrightnessSettingsView()
                case .battery:
                    BatterySettingsView()
                case .keyboard:
                    KeyboardSettingsView()
                case .clipboard:
                    ClipboardSettingsView()
                case .date:
                    DateSettingsView()
                    
                // PREMIUM TRACKERS
                case .media:
                    MediaSettingsView()
                case .wifi:
                    WiFiSettingsView()
                case .bluetooth:
                    BluetoothSettingsView()
                case .privacy:
                    PrivacySettingsView()
                case .theme:
                    ThemeSettingsView()
                case .focus:
                    FocusSettingsView()
                case .peripheral:
                    PeripheralSettingsView()
                case .display:
                    DisplaySettingsView()
                case .macSystem:
                    SystemSettingsView()
                case .trash:
                    TrashSettingsView()
                case .accessory(let name):
                    AccessorySettingsView(deviceName: name)
                }
            }
            .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
            .scrollContentBackground(.hidden)
                    }
        .frame(minWidth: 850, maxWidth: .infinity, minHeight: 620, maxHeight: .infinity)
        .background(WindowAccessor(window: $window))
        .background(VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow).ignoresSafeArea())
        .onChange(of: mediaKeyManager.accessoryBatteryHistory) { _, newHistory in
            if case .accessory(let selectedName) = selection {
                let currentAccessories = Array(Set(newHistory.map { name -> String in
                    if name.hasSuffix(" (Left)") { return String(name.dropLast(7)) }
                    if name.hasSuffix(" (Right)") { return String(name.dropLast(8)) }
                    if name.hasSuffix(" (Case)") { return String(name.dropLast(7)) }
                    return name
                }))
                if !currentAccessories.contains(selectedName) {
                    selection = .general
                }
            }
        }
        .onChange(of: mediaKeyManager.enableBluetooth) { _, isEnabled in
            if !isEnabled {
                if case .accessory(_) = selection {
                    selection = .general
                }
            }
        }
        .onChange(of: window) { _, newWindow in
            if let w = newWindow {
                w.isOpaque = false
                w.backgroundColor = .clear
                w.titlebarAppearsTransparent = true
                w.titleVisibility = .hidden
                w.title = ""
                w.styleMask.insert(.fullSizeContentView)
                w.styleMask.insert(.miniaturizable)
                w.styleMask.insert(.resizable)
                w.minSize = NSSize(width: 850, height: 620)
                
                if w.frame.width < 850 || w.frame.height < 620 {
                    w.setContentSize(NSSize(width: 850, height: 620))
                    w.center()
                }
                
                if NSApp.activationPolicy() != .regular {
                    NSApp.setActivationPolicy(.regular)
                }
                NSApp.activate(ignoringOtherApps: true)
                w.makeKeyAndOrderFront(nil)
                w.level = .normal
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            if let openedWindow = notification.object as? NSWindow, openedWindow == window {
                openedWindow.titleVisibility = .hidden
                openedWindow.title = ""
                if NSApp.activationPolicy() != .regular {
                    NSApp.setActivationPolicy(.regular)
                }
                NSApp.activate(ignoringOtherApps: true)
                window?.level = .normal
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            if let closedWindow = notification.object as? NSWindow, closedWindow == window {
                if let monitor = keyMonitor {
                    NSEvent.removeMonitor(monitor)
                    keyMonitor = nil
                }
                if NSApp.activationPolicy() != .accessory {
                    NSApp.setActivationPolicy(.accessory)
                }
                selection = .general
                WallpaperHelper.clearCache()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenPremiumSettings"))) { _ in
            selection = .premium
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenChangelogSettings"))) { _ in
            selection = .recentChanges
        }
        .onAppear {
            if keyMonitor == nil {
                keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    guard let w = window, event.window == w else {
                        return event
                    }
                    if event.keyCode == 125 || event.keyCode == 126 { // 125 = down, 126 = up
                        if let responder = event.window?.firstResponder,
                           responder is NSTextView || responder is NSTextField {
                            return event
                        }
                        if event.keyCode == 125 {
                            selectNext()
                        } else {
                            selectPrevious()
                        }
                        return nil
                    }
                    return event
                }
            }
            if let target = SettingsView.pendingSelection {
                selection = target
                SettingsView.pendingSelection = nil
            }
        }
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
        }
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































