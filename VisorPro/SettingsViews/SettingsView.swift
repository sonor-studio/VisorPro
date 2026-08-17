import SwiftUI
import AppKit
import AVFoundation
import ServiceManagement

struct SettingsView: View {
    enum SidebarItem: Hashable {
        case general
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
        case settings
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
                
                Section("System") {
                    NavigationLink(value: SidebarItem.settings) {
                        Label {
                            Text("Settings")
                        } icon: {
                            SidebarIcon(systemName: "slider.horizontal.3", color: .gray)
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
                case .settings:
                    AppConfigurationView()
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

