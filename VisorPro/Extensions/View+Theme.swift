import SwiftUI

extension View {
    @ViewBuilder
    func applyTheme(_ theme: String) -> some View {
        if theme == "dark" {
            self.environment(\.colorScheme, .dark)
        } else if theme == "light" {
            self.environment(\.colorScheme, .light)
        } else {
            self // Default to system theme
        }
    }
}
