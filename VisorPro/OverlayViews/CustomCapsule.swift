import SwiftUI

struct CustomCapsule: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = rect.height / 2
        let l = rect.width - rect.height
        
        path.move(to: CGPoint(x: 0, y: r))
        path.addArc(center: CGPoint(x: r, y: r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.addLine(to: CGPoint(x: r + l, y: 0))
        path.addArc(center: CGPoint(x: r + l, y: r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: r, y: rect.height))
        path.addArc(center: CGPoint(x: r, y: r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        
        return path
    }
}
