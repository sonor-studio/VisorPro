import SwiftUI

extension View {
    func glassEffect<S: Shape>(_ material: Material, in shape: S) -> some View {
        self.background(material, in: shape)
            .overlay(
                shape.stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .clipShape(shape)
    }
    
    func glassEffect(_ material: Material) -> some View {
        self.background(material)
    }
}

extension Material {
    // Stub to support the .interactive() syntax from other projects
    func interactive() -> Material {
        return self
    }
}
