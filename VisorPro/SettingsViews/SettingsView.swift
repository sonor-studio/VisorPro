import SwiftUI
import AppKit
import AVFoundation
import ServiceManagement

struct SettingsView: View {
    enum SidebarItem: Hashable {
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
        case peripheral
        case display
        case feedback
        case macSystem
        case about
    }
    
    @State private var selection: SidebarItem? = .general
    @State private var window: NSWindow?
    
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
                }
                
                Section("Trackers") {
                    Label {
                            Text("Volume")
                        } icon: {
                            SidebarIcon(systemName: "speaker.wave.2.fill", color: .blue)
                        }
                    .tag(SidebarItem.volume)
                    Label {
                            Text("Media")
                        } icon: {
                            SidebarIcon(systemName: "playpause.fill", color: .red)
                        }
                    .tag(SidebarItem.media)
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
                    Label {
                            Text("Wi-Fi")
                        } icon: {
                            SidebarIcon(systemName: "wifi", color: .cyan)
                        }
                    .tag(SidebarItem.wifi)
                    Label {
                            Text("Bluetooth")
                        } icon: {
                            SidebarIcon(systemName: "point.3.connected.trianglepath.dotted", color: .indigo)
                        }
                    .tag(SidebarItem.bluetooth)
                    Label {
                            Text("Privacy")
                        } icon: {
                            SidebarIcon(systemName: "hand.raised.fill", color: .blue)
                        }
                    .tag(SidebarItem.privacy)
                    Label {
                            Text("Theme")
                        } icon: {
                            SidebarIcon(systemName: "paintpalette.fill", color: .purple)
                        }
                    .tag(SidebarItem.theme)
                    Label {
                            Text("Peripherals")
                        } icon: {
                            SidebarIcon(systemName: "cable.connector", color: .teal)
                        }
                    .tag(SidebarItem.peripheral)
                    Label {
                            Text("Displays")
                        } icon: {
                            SidebarIcon(systemName: "display.2", color: .blue)
                        }
                    .tag(SidebarItem.display)
                    Label {
                            Text("System")
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
            .frame(minWidth: 150, idealWidth: 180, maxWidth: 210)
            .hideSidebarToggle()
            Group {
                switch selection {
                case .general:
                    GeneralSettingsView()
                case .recentChanges:
                    ChangelogSettingsView()
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
                case .display:
                    DisplaySettingsView()
                case .feedback:
                    FeedbackSettingsView()
                case .macSystem:
                    SystemSettingsView()
                case .about:
                    AboutSettingsView()
                case .none:
                    Text("Select an item")
                        .font(.title)
                        .foregroundColor(.secondary)
                }
            }
            .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
        }
        .frame(minWidth: 850, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity)
        .background(WindowAccessor(window: $window))
        .background(
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .behindWindow)
                Color(NSColor.windowBackgroundColor).opacity(0.25)
            }
            .ignoresSafeArea()
        )
        .onChange(of: window) { _, newWindow in
            if let w = newWindow {
                w.isOpaque = false
                w.backgroundColor = .clear
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

