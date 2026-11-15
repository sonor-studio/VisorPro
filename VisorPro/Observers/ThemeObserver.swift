import SwiftUI

class ThemeObserver {
    private weak var manager: MediaKeyManager?
    
    init(manager: MediaKeyManager) {
        self.manager = manager
        startObserving()
    }
    
    static var ignoreNextChange: Bool = false
    
    private func startObserving() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(themeChanged),
            name: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
    }
    
    @objc private func themeChanged() {
        let isDark: Bool
        if let style = UserDefaults.standard.string(forKey: "AppleInterfaceStyle"), style == "Dark" {
            isDark = true
        } else {
            let appearance = NSApp.effectiveAppearance
            isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
        
        DispatchQueue.main.async {
            OverlayStateRelay.shared.isDarkMode = isDark
        }
        
        if ThemeObserver.ignoreNextChange {
            ThemeObserver.ignoreNextChange = false
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.manager?.triggerThemeIndicator(isDark: isDark)
        }
    }
    
    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
