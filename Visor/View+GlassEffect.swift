import SwiftUI

struct ActiveVisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .popover
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.state = .active
    }
}

extension View {
    func glassEffect<S: InsettableShape>(_ material: Material, in shape: S) -> some View {
        self.background(ActiveVisualEffectView().clipShape(shape))
            .overlay(
                shape.stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
            )
            .modifier(InnerBorderModifier(shape: shape))
            .clipShape(shape)
    }
    
    func glassEffect(_ material: Material) -> some View {
        self.background(ActiveVisualEffectView())
    }
}

struct InnerBorderModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content.overlay(
            shape.strokeBorder(Color.innerBorder.opacity(0.2), lineWidth: 1)
        )
    }
}

extension Color {
    static let innerBorder = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .black : .white
    }))
}

extension Material {
    // Stub to support the .interactive() syntax from other projects
    func interactive() -> Material {
        return self
    }
}
