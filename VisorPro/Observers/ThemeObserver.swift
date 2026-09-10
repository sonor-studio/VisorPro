import SwiftUI

class ThemeObserver {
    private weak var manager: MediaKeyManager?
    
    init(manager: MediaKeyManager) {
        self.manager = manager
        startObserving()
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
        DispatchQueue.main.async { [weak self] in
            let appearance = NSApp.effectiveAppearance
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            self?.manager?.triggerThemeIndicator(isDark: isDark)
        }
    }
    
    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
