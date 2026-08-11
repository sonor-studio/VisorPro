import SwiftUI

struct ActiveVisualEffectView: NSViewRepresentable {
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = blendingMode
        view.state = .active
        view.material = .popover
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.state = .active
    }
}

extension View {
    func glassEffect<S: InsettableShape>(_ material: Material, in shape: S, blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) -> some View {
        self.background(ActiveVisualEffectView(blendingMode: blendingMode).clipShape(shape))
            .overlay(
                shape.strokeBorder(Color.glassBorder, lineWidth: 1)
            )
            .clipShape(shape)
    }
    
    func glassEffect(_ material: Material, blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) -> some View {
        self.background(ActiveVisualEffectView(blendingMode: blendingMode))
    }
}

extension Color {
    static let glassBorder = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor.white.withAlphaComponent(0.15) : NSColor.white.withAlphaComponent(0.35)
    }))
}

extension Material {
    // Stub to support the .interactive() syntax from other projects
    func interactive() -> Material {
        return self
    }
}
