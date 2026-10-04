import SwiftUI

struct ThemeApplierModifier: ViewModifier {
    @Environment(\.colorScheme) var systemColorScheme
    var theme: String
    
    func body(content: Content) -> some View {
        content.environment(\.colorScheme, theme == "dark" ? .dark : (theme == "light" ? .light : systemColorScheme))
    }
}

extension View {
    func applyTheme(_ theme: String) -> some View {
        self.modifier(ThemeApplierModifier(theme: theme))
    }
}