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
    @ViewBuilder
    func visorGlassEffect<S: InsettableShape>(_ material: Material = .regularMaterial, in shape: S, blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(shape.fill(material))
                .background(ActiveVisualEffectView(blendingMode: blendingMode).clipShape(shape))
                .overlay(
                    shape.strokeBorder(Color.glassBorder, lineWidth: 1)
                )
                .clipShape(shape)
        }
    }
    
    @ViewBuilder
    func visorGlassEffect(_ material: Material = .regularMaterial, blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular)
        } else {
            self.background(material)
                .background(ActiveVisualEffectView(blendingMode: blendingMode))
        }
    }
}

extension Color {
    static let glassBorder = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor.white.withAlphaComponent(0.2) : NSColor.white.withAlphaComponent(0.35)
    }))
}

extension Material {
    // Stub to support the .interactive() syntax from other projects
    func interactive() -> Material {
        return self
    }
}


import SwiftUI

struct NativeGlassBackgroundModifier: ViewModifier {
    var inShape: Capsule = Capsule() // default
    
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
        }
    }
}

extension View {
    func nativeGlassBackground() -> some View {
        self.modifier(NativeGlassBackgroundModifier())
    }
}
