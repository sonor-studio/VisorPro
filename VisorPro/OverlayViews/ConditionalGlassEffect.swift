import SwiftUI

struct ConditionalGlassEffect: ViewModifier {
    var isActive: Bool
    func body(content: Content) -> some View {
        content.background(
            Color.clear.background(isActive ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.thinMaterial))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.glassBorder, lineWidth: 1))
        )
    }
}
