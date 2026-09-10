import SwiftUI

@available(macOS 14.0, *)
struct TestShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r = Rectangle()
        let c = Circle()
        let s = r.subtracting(c)
        return s.path(in: rect)
    }
}
print("Compiles!")
