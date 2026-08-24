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
                    NavigationLink(value: SidebarItem.recentChanges) {
                        Label {
                            Text("Changelog")
                        } icon: {
                            SidebarIcon(systemName: "clock.arrow.circlepath", color: .indigo)
                        }
                    }
                    NavigationLink(value: SidebarItem.feedback) {
                        Label {
                            Text("Feedback")
                        } icon: {
                            SidebarIcon(systemName: "envelope.fill", color: .blue)
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
                    NavigationLink(value: SidebarItem.keyboardBrightness) {
                        Label {
                            Text("Keyboard Brightness")
                        } icon: {
                            SidebarIcon(systemName: "lightbulb.fill", color: .orange)
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
                    NavigationLink(value: SidebarItem.display) {
                        Label {
                            Text("Displays")
                        } icon: {
                            SidebarIcon(systemName: "display.2", color: .blue)
                        }
                    }
                    NavigationLink(value: SidebarItem.macSystem) {
                        Label {
                            Text("System")
                        } icon: {
                            SidebarIcon(systemName: "cpu", color: .purple)
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
                case .recentChanges:
                    Text("Ostatnie zmiany (puste)")
                        .font(.title)
                        .foregroundColor(.secondary)
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
                case .none:
                    Text("Select an item")
                        .font(.title)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
        }
        .frame(minWidth: 700, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity)
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
                w.minSize = NSSize(width: 700, height: 500)
                
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

