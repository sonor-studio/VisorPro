import SwiftUI

struct AlwaysActiveVisualEffectView: NSViewRepresentable {
    // Default material set to .popover which is designed for floating transient UI
    // and is completely immune to Window Server background desaturation/dimming.
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        
        // Enforce CoreAnimation layer backing to lock in full rendering budget
        view.wantsLayer = true
        view.layerContentsRedrawPolicy = .onSetNeedsDisplay
        
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        if nsView.material != material {
            nsView.material = material
        }
        if nsView.blendingMode != blendingMode {
            nsView.blendingMode = blendingMode
        }
        if nsView.state != .active {
            nsView.state = .active
        }
    }
}

extension View {
    func customAlwaysActiveGlass() -> some View {
        self.background(AlwaysActiveVisualEffectView())
    }
}

extension View {
    @ViewBuilder
    func visorGlassEffect<S: InsettableShape>(_ material: Material = .regularMaterial, in shape: S, blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(shape.fill(material))
                .background(AlwaysActiveVisualEffectView(blendingMode: blendingMode).clipShape(shape))
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
                .background(AlwaysActiveVisualEffectView(blendingMode: blendingMode))
        }
    }

    @ViewBuilder
    func activeMaterialAppearanceIfAvailable() -> some View {
        if #available(macOS 15.0, *) {
            self.materialActiveAppearance(.active)
                .environment(\.controlActiveState, .key)
        } else {
            self.environment(\.controlActiveState, .key)
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
