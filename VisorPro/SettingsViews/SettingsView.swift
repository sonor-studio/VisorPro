import SwiftUI
import AppKit
import AVFoundation
import ServiceManagement

var hasShownNoticeThisSession = false

struct SettingsView: View {
    enum SidebarItem: Hashable {
        case premium
        case general
        case recentChanges
        case volume
        case brightness
        case keyboardBrightness
        case battery
        case keyboard
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
        case about
    }
    
    @State private var selection: SidebarItem? = .general
    @State private var window: NSWindow?
    @AppStorage("PremiumLicenseKey") private var savedLicenseKey = ""
    @AppStorage("hasCompletedWelcome") private var hasCompletedWelcome = false
    @AppStorage("hasSeenEarlyAdopterNoticeV2") private var hasSeenEarlyAdopterNotice = false
    @State private var showingEarlyAdopterNotice = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HSplitView {
            List(selection: $selection) {
                Section("App Settings") {
                    Label {
                            Text("General")
                        } icon: {
                            SidebarIcon(systemName: "gearshape.fill", color: .gray)
                        }
                    .tag(SidebarItem.general)
                    Label {
                            Text("Changelog")
                        } icon: {
                            SidebarIcon(systemName: "clock.arrow.circlepath", color: .indigo)
                        }
                    .tag(SidebarItem.recentChanges)
                    Label {
                            Text("Feedback")
                        } icon: {
                            SidebarIcon(systemName: "envelope.fill", color: .blue)
                        }
                    .tag(SidebarItem.feedback)
                    Label {
                            Text("Premium")
                        } icon: {
                            SidebarIcon(systemName: "checkmark.seal.fill", color: .green)
                        }
                    .tag(SidebarItem.premium)
                }
                
                Section("Trackers") {
                    Label {
                            Text("Volume")
                        } icon: {
                            SidebarIcon(systemName: "speaker.wave.2.fill", color: .blue)
                        }
                    .tag(SidebarItem.volume)
                    Label {
                            Text("Brightness")
                        } icon: {
                            SidebarIcon(systemName: "sun.max.fill", color: .yellow)
                        }
                    .tag(SidebarItem.brightness)
                    Label {
                            Text("Keyboard Brightness")
                        } icon: {
                            SidebarIcon(systemName: "lightbulb.fill", color: .orange)
                        }
                    .tag(SidebarItem.keyboardBrightness)
                    Label {
                            Text("Battery")
                        } icon: {
                            SidebarIcon(systemName: "battery.100", color: .green)
                        }
                    .tag(SidebarItem.battery)
                    Label {
                            Text("Keyboard")
                        } icon: {
                            SidebarIcon(systemName: "keyboard", color: .orange)
                        }
                    .tag(SidebarItem.keyboard)
                    
                    // --- PREMIUM TRACKERS ---
                    Label {
                            HStack { Text("Media"); Spacer(); }
                        } icon: {
                            SidebarIcon(systemName: "playpause.fill", color: .red)
                        }
                    .tag(SidebarItem.media)
                    Label {
                            HStack { Text("Wi-Fi"); Spacer(); }
                        } icon: {
                            SidebarIcon(systemName: "wifi", color: .cyan)
                        }
                    .tag(SidebarItem.wifi)
                    Label {
                            HStack { Text("Bluetooth"); Spacer(); }
                        } icon: {
                            SidebarIcon(systemName: "point.3.connected.trianglepath.dotted", color: .indigo)
                        }
                    .tag(SidebarItem.bluetooth)
                    Label {
                            HStack { Text("Privacy"); Spacer(); }
                        } icon: {
                            SidebarIcon(systemName: "hand.raised.fill", color: .blue)
                        }
                    .tag(SidebarItem.privacy)
                    Label {
                            HStack { Text("Theme"); Spacer(); }
                        } icon: {
                            SidebarIcon(systemName: "paintpalette.fill", color: .purple)
                        }
                    .tag(SidebarItem.theme)
                    Label {
                            HStack { Text("Focus Mode"); Spacer(); }
                        } icon: {
                            SidebarIcon(systemName: "moon.fill", color: .indigo)
                        }
                    .tag(SidebarItem.focus)
                    Label {
                            HStack { Text("Peripherals"); Spacer(); }
                        } icon: {
                            SidebarIcon(systemName: "cable.connector", color: .teal)
                        }
                    .tag(SidebarItem.peripheral)
                    Label {
                            HStack { Text("Displays"); Spacer(); }
                        } icon: {
                            SidebarIcon(systemName: "display.2", color: .blue)
                        }
                    .tag(SidebarItem.display)
                    Label {
                            HStack { Text("System"); Spacer(); }
                        } icon: {
                            SidebarIcon(systemName: "cpu", color: .purple)
                        }
                    .tag(SidebarItem.macSystem)
                }
                
                Section("Information") {
                    Label {
                        Text("About")
                    } icon: {
                        SidebarIcon(systemName: "info.circle.fill", color: .gray)
                    }
                    .tag(SidebarItem.about)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
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
                    
                case .none:
                    Text("Select an item")
                        .font(.title)
                        .foregroundColor(.secondary)
                }
            }
            .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
            .scrollContentBackground(.hidden)
                    }
        .frame(minWidth: 850, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity)
        .background(WindowAccessor(window: $window))
        .background(VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow).ignoresSafeArea())
        .onChange(of: window) { _, newWindow in
            if let w = newWindow {
                w.isOpaque = false
                w.backgroundColor = .clear
                w.titlebarAppearsTransparent = true
                w.styleMask.insert(.fullSizeContentView)
                w.styleMask.insert(.miniaturizable)
                w.styleMask.insert(.resizable)
                w.minSize = NSSize(width: 850, height: 500)
                
                if w.frame.width < 850 || w.frame.height < 500 {
                    w.setContentSize(NSSize(width: 850, height: 500))
                    w.center()
                }
                
                if selection == .none {
                    selection = .general
                }
                
                NSApp.setActivationPolicy(.regular)
                
                NSApp.activate(ignoringOtherApps: true)
                w.makeKeyAndOrderFront(nil)
                w.level = .normal
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            if let openedWindow = notification.object as? NSWindow, openedWindow == window {
                if selection == .none {
                    selection = .general
                }
                
                if NSApp.activationPolicy() != .regular {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    window?.level = .normal
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            if let closedWindow = notification.object as? NSWindow, closedWindow == window {
                NSApp.setActivationPolicy(.accessory)
                
                selection = .none
                WallpaperHelper.clearCache()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenPremiumSettings"))) { _ in
            selection = .premium
        }
        .onAppear {
            checkAndShowEarlyAdopterNotice()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkAndShowEarlyAdopterNotice()
        }
        .sheet(isPresented: $showingEarlyAdopterNotice) {
            EarlyAdopterNoticeSheet(
                isPresented: $showingEarlyAdopterNotice,
                hasSeenNotice: $hasSeenEarlyAdopterNotice,
                savedLicenseKey: $savedLicenseKey
            )
        }
    }
    
    private func checkAndShowEarlyAdopterNotice() {
        if savedLicenseKey.isEmpty && hasCompletedWelcome && !hasSeenEarlyAdopterNotice && !hasShownNoticeThisSession {
            // Prevent spamming if it's already showing
            guard !showingEarlyAdopterNotice else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if savedLicenseKey.isEmpty && hasCompletedWelcome && !hasSeenEarlyAdopterNotice && !hasShownNoticeThisSession {
                    showingEarlyAdopterNotice = true
                    hasShownNoticeThisSession = true
                }
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






























import SwiftUI

