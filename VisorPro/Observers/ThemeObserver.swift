import SwiftUI

class ThemeObserver {
    private weak var manager: MediaKeyManager?
    private var lastObservedDarkMode: Bool?
    
    init(manager: MediaKeyManager) {
        self.manager = manager
        let initialDark = ThemeObserver.isSystemInDarkMode()
        self.lastObservedDarkMode = initialDark
        OverlayStateRelay.shared.isDarkMode = initialDark
        startObserving()
    }
    
    static var ignoreNextChange: Bool = false
    
    static func isSystemInDarkMode() -> Bool {
        if let style = CFPreferencesCopyAppValue("AppleInterfaceStyle" as CFString, kCFPreferencesAnyApplication) as? String, style == "Dark" {
            return true
        }
        if let style = UserDefaults.standard.string(forKey: "AppleInterfaceStyle"), style == "Dark" {
            return true
        }
        let appearance = NSApp.effectiveAppearance
        return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
    
    private func startObserving() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(themeChanged),
            name: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
    }
    
    @objc private func themeChanged() {
        let isDark = ThemeObserver.isSystemInDarkMode()
        
        DispatchQueue.main.async {
            OverlayStateRelay.shared.isDarkMode = isDark
        }
        
        if ThemeObserver.ignoreNextChange {
            ThemeObserver.ignoreNextChange = false
            lastObservedDarkMode = isDark
            return
        }
        
        if let last = lastObservedDarkMode, last == isDark {
            return
        }
        lastObservedDarkMode = isDark
        
        DispatchQueue.main.async { [weak self] in
            self?.manager?.triggerThemeIndicator(isDark: isDark)
        }
    }
    
    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
