import AppKit
import Combine
import CoreLocation

@MainActor
final class MenuBarManager: NSObject, NSMenuDelegate {
    static let shared = MenuBarManager()
    
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private var cancellables = Set<AnyCancellable>()
    var openDashboardAction: (() -> Void)?
    
    private override init() {
        super.init()
    }
    
    func setup(openDashboard: @escaping () -> Void) {
        self.openDashboardAction = openDashboard
        guard statusItem == nil else { return }
        
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(named: "MenuBarIcon")
            image?.isTemplate = true
            button.image = image
        }
        
        menu.delegate = self
        item.menu = menu
        self.statusItem = item
        
        updateVisibility()
        
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateVisibility()
            }
            .store(in: &cancellables)
    }
    
    func updateVisibility() {
        let isVisible = UserDefaults.standard.object(forKey: "showMenuBarIcon") as? Bool ?? true
        statusItem?.isVisible = isVisible
    }
    
    // MARK: - NSMenuDelegate
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let versionItem = NSMenuItem(title: "Visor Pro v\(appVersion)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quick Toggles Submenu
        let quickTogglesItem = NSMenuItem(title: "Quick Toggles", action: nil, keyEquivalent: "")
        let quickTogglesMenu = NSMenu(title: "Quick Toggles")
        quickTogglesItem.submenu = quickTogglesMenu
        menu.addItem(quickTogglesItem)
        
        populateQuickToggles(into: quickTogglesMenu)
        
        // Show Last Overlay
        let showLastItem = NSMenuItem(title: "Show Last Overlay", action: #selector(showLastOverlayAction), keyEquivalent: "")
        showLastItem.target = self
        showLastItem.isEnabled = OverlayStateRelay.shared.canShowLastOverlay
        
        let shortcut = MediaKeyManager.shared.lastOverlayShortcutString
        let keyChar = shortcut.keyEquivalentCharacter
        if !keyChar.isEmpty {
            showLastItem.keyEquivalent = keyChar
            showLastItem.keyEquivalentModifierMask = shortcut.eventModifierFlags
        }
        menu.addItem(showLastItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Dashboard
        let dashboardItem = NSMenuItem(title: "Dashboard", action: #selector(openDashboardMenuAction), keyEquivalent: "")
        dashboardItem.target = self
        menu.addItem(dashboardItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitAppAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    private func populateQuickToggles(into subMenu: NSMenu) {
        let manager = MediaKeyManager.shared
        
        addToggleItem(to: subMenu, title: "Volume", isOn: manager.enableVolume, action: #selector(toggleVolume))
        addToggleItem(to: subMenu, title: "Brightness", isOn: manager.enableBrightness, action: #selector(toggleBrightness))
        addToggleItem(to: subMenu, title: "Keyboard Brightness", isOn: manager.enableKeyboardBrightness, action: #selector(toggleKeyboardBrightness))
        addToggleItem(to: subMenu, title: "Battery", isOn: manager.enableBattery, action: #selector(toggleBattery))
        addToggleItem(to: subMenu, title: "Keyboard", isOn: manager.enableKeyboard, action: #selector(toggleKeyboard))
        addToggleItem(to: subMenu, title: "Clipboard", isOn: manager.enableClipboard, action: #selector(toggleClipboard))
        
        let savedLicenseKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        guard !savedLicenseKey.isEmpty else { return }
        
        subMenu.addItem(NSMenuItem.separator())
        
        addToggleItem(to: subMenu, title: "Media", isOn: manager.enableMediaNotification, action: #selector(toggleMedia))
        addToggleItem(to: subMenu, title: "Wi-Fi", isOn: manager.enableWiFi, action: #selector(toggleWiFi))
        addToggleItem(to: subMenu, title: "Bluetooth", isOn: manager.enableBluetooth, action: #selector(toggleBluetooth))
        addToggleItem(to: subMenu, title: "Privacy", isOn: manager.enablePrivacy, action: #selector(togglePrivacy))
        addToggleItem(to: subMenu, title: "Theme", isOn: manager.enableTheme, action: #selector(toggleTheme))
        addToggleItem(to: subMenu, title: "Focus Mode", isOn: manager.enableFocus, action: #selector(toggleFocus))
        addToggleItem(to: subMenu, title: "Peripherals", isOn: manager.enablePeripheral, action: #selector(togglePeripherals))
        addToggleItem(to: subMenu, title: "Displays", isOn: manager.enableDisplay, action: #selector(toggleDisplays))
        addToggleItem(to: subMenu, title: "Date & Time", isOn: manager.enableDate, action: #selector(toggleDate))
        
        let showSystem = UserDefaults.standard.object(forKey: "showSystemModule") as? Bool ?? true
        addToggleItem(to: subMenu, title: "System", isOn: showSystem, action: #selector(toggleSystem))
        
        let showTrash = UserDefaults.standard.object(forKey: "showTrashModule") as? Bool ?? true
        addToggleItem(to: subMenu, title: "Trash", isOn: showTrash, action: #selector(toggleTrash))
        
        if !manager.accessorySettings.isEmpty {
            subMenu.addItem(NSMenuItem.separator())
            let accessoriesItem = NSMenuItem(title: "Accessories", action: nil, keyEquivalent: "")
            let accessoriesMenu = NSMenu(title: "Accessories")
            accessoriesItem.submenu = accessoriesMenu
            subMenu.addItem(accessoriesItem)
            
            for key in manager.accessorySettings.keys.sorted() {
                let isOn = manager.accessorySettings[key]?.enableOverlay ?? true
                let accItem = NSMenuItem(title: key, action: #selector(toggleAccessoryItem(_:)), keyEquivalent: "")
                accItem.target = self
                accItem.representedObject = key
                accItem.state = isOn ? .on : .off
                accessoriesMenu.addItem(accItem)
            }
        }
    }
    
    private func addToggleItem(to menu: NSMenu, title: String, isOn: Bool, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = isOn ? .on : .off
        menu.addItem(item)
    }
    
    // MARK: - Actions
    
    @objc private func toggleVolume() {
        MediaKeyManager.shared.enableVolume.toggle()
    }
    
    @objc private func toggleBrightness() {
        MediaKeyManager.shared.enableBrightness.toggle()
    }
    
    @objc private func toggleKeyboardBrightness() {
        MediaKeyManager.shared.enableKeyboardBrightness.toggle()
    }
    
    @objc private func toggleBattery() {
        MediaKeyManager.shared.enableBattery.toggle()
    }
    
    @objc private func toggleKeyboard() {
        MediaKeyManager.shared.enableKeyboard.toggle()
    }
    
    @objc private func toggleClipboard() {
        MediaKeyManager.shared.enableClipboard.toggle()
    }
    
    @objc private func toggleMedia() {
        MediaKeyManager.shared.enableMediaNotification.toggle()
    }
    
    @objc private func toggleWiFi() {
        let manager = MediaKeyManager.shared
        if !manager.enableWiFi {
            if PermissionHelper.isLocationNotDetermined() {
                PermissionHelper.sharedLocationManager.requestAlwaysAuthorization()
                manager.enableWiFi = true
            } else if PermissionHelper.hasLocationPermission() {
                manager.enableWiFi = true
            } else {
                manager.enableWiFi = false
                PermissionHelper.openPrivacySettings(for: "Location")
                
                let alert = NSAlert()
                alert.messageText = "Location Access Required"
                alert.informativeText = "To read the Wi-Fi network name, VisorPro needs location access. Please enable it in System Settings > Privacy & Security > Location Services."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        } else {
            manager.enableWiFi = false
        }
    }
    
    @objc private func toggleBluetooth() {
        MediaKeyManager.shared.enableBluetooth.toggle()
    }
    
    @objc private func togglePrivacy() {
        MediaKeyManager.shared.enablePrivacy.toggle()
    }
    
    @objc private func toggleTheme() {
        MediaKeyManager.shared.enableTheme.toggle()
    }
    
    @objc private func toggleFocus() {
        MediaKeyManager.shared.enableFocus.toggle()
    }
    
    @objc private func togglePeripherals() {
        MediaKeyManager.shared.enablePeripheral.toggle()
    }
    
    @objc private func toggleDisplays() {
        MediaKeyManager.shared.enableDisplay.toggle()
    }
    
    @objc private func toggleDate() {
        MediaKeyManager.shared.enableDate.toggle()
    }
    
    @objc private func toggleSystem() {
        let current = UserDefaults.standard.object(forKey: "showSystemModule") as? Bool ?? true
        UserDefaults.standard.set(!current, forKey: "showSystemModule")
    }
    
    @objc private func toggleTrash() {
        let current = UserDefaults.standard.object(forKey: "showTrashModule") as? Bool ?? true
        UserDefaults.standard.set(!current, forKey: "showTrashModule")
    }
    
    @objc private func toggleAccessoryItem(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              var settings = MediaKeyManager.shared.accessorySettings[key] else { return }
        settings.enableOverlay.toggle()
        MediaKeyManager.shared.accessorySettings[key] = settings
    }
    
    @objc private func showLastOverlayAction() {
        MediaKeyManager.shared.showLastViewedOverlay()
    }
    
    @objc private func openDashboardMenuAction() {
        openDashboardAction?()
    }
    
    @objc private func quitAppAction() {
        NSApplication.shared.terminate(nil)
    }
}
