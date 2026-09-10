import SwiftUI

struct TestShape: InsettableShape, Sendable {
    var animatableData: CGFloat {
        get { 0 }
        set { }
    }
    func inset(by amount: CGFloat) -> TestShape { return self }
    func path(in rect: CGRect) -> Path { return Path() }
}
