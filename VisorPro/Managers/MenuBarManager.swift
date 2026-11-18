import AppKit
import Combine
import CoreLocation

@MainActor
final class MenuBarManager: NSObject, NSMenuDelegate, NSMenuItemValidation {
    static let shared = MenuBarManager()
    
    private var statusItem: NSStatusItem?
    var statusItemButton: NSStatusBarButton? {
        statusItem?.button
    }
    private let menu = NSMenu()
    private var cancellables = Set<AnyCancellable>()
    var openDashboardAction: (() -> Void)?
    var openChangelogAction: (() -> Void)?
    
    private override init() {
        super.init()
    }
    
    private var originalMenuBarImage: NSImage?
    private var customIconHostingView: NSView?
    private var activeOverlaySymbolName: String?
    private var pillView: MenuBarPillView?
    
    func setup(openDashboard: @escaping () -> Void, openChangelog: (() -> Void)? = nil) {
        self.openDashboardAction = openDashboard
        self.openChangelogAction = openChangelog
        guard statusItem == nil else { return }
        
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let orig = NSImage(named: "MenuBarIcon")
            orig?.isTemplate = true
            self.originalMenuBarImage = orig
            
            // Set initial fixed-size template image
            button.image = makeFixedImage(from: orig)
            button.toolTip = "VisorPro"
            button.wantsLayer = true
            button.layer?.masksToBounds = false
            
            // Capsule pill highlight subview placed behind the native button cell drawing
            let pill = MenuBarPillView(frame: button.bounds)
            pill.autoresizingMask = [.width, .height]
            button.addSubview(pill, positioned: .below, relativeTo: nil)
            self.pillView = pill
        }
        
        menu.delegate = self
        item.menu = menu
        self.statusItem = item
        
        rebuildMenu()
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
    
    // MARK: - Animated Menu Bar Icon Morph for System Style Overlays
    
    /// Morph the menu bar icon into the active overlay's symbol when a System-style overlay appears,
    /// or morph it back to the original VisorPro icon when all overlays disappear.
    func morphIcon(to symbolName: String?) {
        guard let button = statusItemButton,
              let buttonLayer = button.layer,
              let pillView = self.pillView,
              let pillLayer = pillView.layer else { return }
        
        let isSystemTransformEnabled = UserDefaults.standard.object(forKey: "systemMenuBarIconTransform") as? Bool ?? true
        let isSystemStyle = (MediaKeyManager.shared.effectiveOverlayStyle == "system")
        
        // If disabled or not in system style, always reset to original icon if transformed
        guard isSystemTransformEnabled && isSystemStyle else {
            if activeOverlaySymbolName != nil {
                resetIconImmediately()
            }
            return
        }
        
        // If symbol hasn't changed, do nothing
        if activeOverlaySymbolName == symbolName { return }
        activeOverlaySymbolName = symbolName
        
        pillView.updatePillColor()
        
        // Ensure proper layer anchor point
        buttonLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        buttonLayer.position = CGPoint(x: button.frame.midX, y: button.frame.midY)
        
        pillLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        pillLayer.position = CGPoint(x: button.bounds.midX, y: button.bounds.midY)
        
        // 1. Shrink icon and pill smoothly
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.18)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0))
        
        let shrinkAnim = CAKeyframeAnimation(keyPath: "transform.scale")
        shrinkAnim.values = [1.0, 0.2]
        shrinkAnim.keyTimes = [0.0, 1.0]
        shrinkAnim.isRemovedOnCompletion = false
        shrinkAnim.fillMode = .forwards
        
        let fadeOut = CAKeyframeAnimation(keyPath: "opacity")
        fadeOut.values = [1.0, 0.0]
        fadeOut.keyTimes = [0.0, 1.0]
        fadeOut.isRemovedOnCompletion = false
        fadeOut.fillMode = .forwards
        
        CATransaction.setCompletionBlock { [weak self, weak button, weak pillView] in
            guard let self = self, let button = button, let pillLayer = pillView?.layer else { return }
            
            let isHighlightEnabled = UserDefaults.standard.object(forKey: "systemMenuBarIconHighlight") as? Bool ?? true
            let isOverlay = (symbolName != nil)
            
            // Switch image on the native NSStatusBarButton
            self.applyIconDirect(symbolName: symbolName)
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            pillLayer.opacity = (isOverlay && isHighlightEnabled) ? 1.0 : 0.0
            button.layer?.removeAllAnimations()
            pillLayer.removeAllAnimations()
            CATransaction.commit()
            
            // 2. Grow new icon and pill out smoothly
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.24)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0))
            
            let growAnim = CAKeyframeAnimation(keyPath: "transform.scale")
            growAnim.values = [0.2, 1.04, 1.0]
            growAnim.keyTimes = [0.0, 0.7, 1.0]
            growAnim.isRemovedOnCompletion = false
            growAnim.fillMode = .forwards
            
            let fadeIn = CAKeyframeAnimation(keyPath: "opacity")
            fadeIn.values = [0.0, 1.0]
            fadeIn.keyTimes = [0.0, 1.0]
            fadeIn.isRemovedOnCompletion = false
            fadeIn.fillMode = .forwards
            
            button.layer?.add(growAnim, forKey: "growScale")
            button.layer?.add(fadeIn, forKey: "growFade")
            
            if isOverlay && isHighlightEnabled {
                pillLayer.add(growAnim, forKey: "pillGrowScale")
                pillLayer.add(fadeIn, forKey: "pillGrowFade")
            }
            
            CATransaction.commit()
        }
        
        buttonLayer.add(shrinkAnim, forKey: "shrinkScale")
        buttonLayer.add(fadeOut, forKey: "shrinkFade")
        if pillLayer.opacity > 0.0 {
            pillLayer.add(shrinkAnim, forKey: "pillShrinkScale")
            pillLayer.add(fadeOut, forKey: "pillShrinkFade")
        }
        CATransaction.commit()
    }
    
    private func applyIconDirect(symbolName: String?) {
        guard let button = statusItemButton else { return }
        if let symbolName = symbolName,
           let sfImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Overlay Status") {
            let config = NSImage.SymbolConfiguration(pointSize: 13.0, weight: .semibold)
            let configured = sfImage.withSymbolConfiguration(config) ?? sfImage
            configured.isTemplate = true
            button.image = makeFixedImage(from: configured)
        } else {
            let orig = originalMenuBarImage ?? NSImage(named: "MenuBarIcon")
            orig?.isTemplate = true
            button.image = makeFixedImage(from: orig)
        }
    }
    
    private func makeFixedImage(from source: NSImage?) -> NSImage? {
        guard let source = source else { return nil }
        // 24 width slightly widens the button bounds naturally (by ~2pt) without hardcoding or breaking button.window
        let fixed = NSImage(size: NSSize(width: 24, height: 16), flipped: false) { rect in
            let targetSize = source.size
            let drawRect = NSRect(
                x: (rect.width - targetSize.width) / 2.0,
                y: (rect.height - targetSize.height) / 2.0,
                width: targetSize.width,
                height: targetSize.height
            )
            source.draw(in: drawRect)
            return true
        }
        fixed.isTemplate = true
        return fixed
    }
    
    private func resetIconImmediately() {
        activeOverlaySymbolName = nil
        applyIconDirect(symbolName: nil)
        statusItemButton?.layer?.removeAllAnimations()
        statusItemButton?.layer?.transform = CATransform3DIdentity
        statusItemButton?.layer?.opacity = 1.0
        pillView?.layer?.removeAllAnimations()
        pillView?.layer?.opacity = 0.0
    }
    
    // MARK: - NSMenuDelegate
    
    func menuWillOpen(_ menu: NSMenu) {
        if NSApp.activationPolicy() != .accessory {
            NSApp.setActivationPolicy(.accessory)
        }
        rebuildMenu()
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }
    
    private func rebuildMenu() {
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
        showLastItem.isEnabled = MediaKeyManager.shared.canShowLastOverlay
        
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
        
        // What's New
        let whatsNewItem = NSMenuItem(title: "What's New...", action: #selector(openWhatsNewMenuAction), keyEquivalent: "")
        whatsNewItem.target = self
        menu.addItem(whatsNewItem)
        
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
    
    // MARK: - NSMenuItemValidation
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(showLastOverlayAction) {
            return MediaKeyManager.shared.canShowLastOverlay
        }
        return true
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
        MediaKeyManager.shared.enableWiFi.toggle()
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
        guard MediaKeyManager.shared.canShowLastOverlay else { return }
        MediaKeyManager.shared.showLastViewedOverlay()
    }
    
    @objc private func openDashboardMenuAction() {
        openDashboardAction?()
    }
    
    @objc private func openWhatsNewMenuAction() {
        openChangelogAction?()
    }
    
    @objc private func quitAppAction() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Dedicated Subviews for Menu Bar Icon and Capsule Pill

/// Layer-backed native macOS translucent pill highlight behind the active status item.
private final class MenuBarPillView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        self.wantsLayer = true
        self.layer?.cornerCurve = .circular
        self.layer?.masksToBounds = true
        self.layer?.opacity = 0.0
        updateCornerRadius()
        updatePillColor()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
    
    func updateCornerRadius() {
        self.layer?.cornerRadius = self.bounds.height / 2.0
    }
    
    override func layout() {
        super.layout()
        if let superview = self.superview {
            // Expand vertically by 1pt up and down (2px Retina) to match system height perfectly,
            // while keeping horizontal width exactly matching superview bounds so ends do not get clipped.
            let targetFrame = NSRect(
                x: 0,
                y: -1.0,
                width: superview.bounds.width,
                height: superview.bounds.height + 2.0
            )
            if self.frame != targetFrame {
                self.frame = targetFrame
            }
        }
        updateCornerRadius()
    }
    
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updatePillColor()
    }
    
    func updatePillColor() {
        // 10% opacity white (90% transparency)
        let color = NSColor.white.withAlphaComponent(0.10)
        self.layer?.backgroundColor = color.cgColor
    }
}
