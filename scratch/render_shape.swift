import SwiftUI
import AppKit

struct BendedCornerShape: InsettableShape {
    var radius: CGFloat
    var bendAmount: CGFloat
    var absoluteCutoutCenter: CGPoint
    var cutoutRadius: CGFloat
    var frameOffset: CGPoint
    var insetAmount: CGFloat = 0
    
    func inset(by amount: CGFloat) -> BendedCornerShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
    
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = max(0, radius - insetAmount)
        let w = rect.width
        let h = rect.height
        
        p.move(to: CGPoint(x: w - r - insetAmount, y: insetAmount))
        p.addArc(center: CGPoint(x: w - r - insetAmount, y: insetAmount + r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        
        p.addLine(to: CGPoint(x: w - insetAmount, y: h - r - insetAmount))
        p.addArc(center: CGPoint(x: w - r - insetAmount, y: h - r - insetAmount), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        
        p.addLine(to: CGPoint(x: insetAmount + r, y: h - insetAmount))
        p.addArc(center: CGPoint(x: insetAmount + r, y: h - r - insetAmount), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        
        if bendAmount > 0.001 {
            let cx = absoluteCutoutCenter.x - frameOffset.x
            let cy = absoluteCutoutCenter.y - frameOffset.y
            let baseCutout = 13.0 * bendAmount
            let R1 = baseCutout + insetAmount
            
            let C2_x = insetAmount + r
            let C2_y = insetAmount + r
            let R2 = r
            
            let dx = C2_x - cx
            let dy = C2_y - cy
            let d = sqrt(dx*dx + dy*dy)
            
            if d < R1 + R2 && d > abs(R1 - R2) {
                let a = (R1*R1 - R2*R2 + d*d) / (2 * d)
                let hSquared = R1*R1 - a*a
                if hSquared > 0 {
                    let h_val = sqrt(hSquared)
                    
                    let P2_x = cx + a * dx / d
                    let P2_y = cy + a * dy / d
                    
                    let i1_x = P2_x + h_val * dy / d
                    let i1_y = P2_y - h_val * dx / d
                    
                    let i2_x = P2_x - h_val * dy / d
                    let i2_y = P2_y + h_val * dx / d
                    
                    let intA = i1_y > i2_y ? CGPoint(x: i1_x, y: i1_y) : CGPoint(x: i2_x, y: i2_y)
                    let intB = i1_y > i2_y ? CGPoint(x: i2_x, y: i2_y) : CGPoint(x: i1_x, y: i1_y)
                    
                    p.addLine(to: CGPoint(x: insetAmount, y: insetAmount + r))
                    
                    func norm(_ a: CGFloat) -> CGFloat { return a < 0 ? a + 2 * .pi : a }
                    
                    let angleStart1 = norm(atan2(0, -r))
                    let angleEnd1 = norm(atan2(intA.y - C2_y, intA.x - C2_x))
                    p.addArc(center: CGPoint(x: C2_x, y: C2_y), radius: R2, startAngle: Angle(radians: Double(angleStart1)), endAngle: Angle(radians: Double(angleEnd1)), clockwise: false)
                    
                    let angleStart2 = atan2(intA.y - cy, intA.x - cx)
                    let angleEnd2 = atan2(intB.y - cy, intB.x - cx)
                    p.addArc(center: CGPoint(x: cx, y: cy), radius: R1, startAngle: Angle(radians: Double(angleStart2)), endAngle: Angle(radians: Double(angleEnd2)), clockwise: true)
                    
                    let angleStart3 = norm(atan2(intB.y - C2_y, intB.x - C2_x))
                    let angleEnd3 = norm(atan2(-r, 0))
                    p.addArc(center: CGPoint(x: C2_x, y: C2_y), radius: R2, startAngle: Angle(radians: Double(angleStart3)), endAngle: Angle(radians: Double(angleEnd3)), clockwise: false)
                } else {
                    p.addLine(to: CGPoint(x: insetAmount, y: insetAmount + r))
                    p.addArc(center: CGPoint(x: insetAmount + r, y: insetAmount + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(-90), clockwise: false)
                }
            } else {
                p.addLine(to: CGPoint(x: insetAmount, y: insetAmount + r))
                p.addArc(center: CGPoint(x: insetAmount + r, y: insetAmount + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(-90), clockwise: false)
            }
        } else {
            p.addLine(to: CGPoint(x: insetAmount, y: insetAmount + r))
            p.addArc(center: CGPoint(x: insetAmount + r, y: insetAmount + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(-90), clockwise: false)
        }
        
        p.closeSubpath()
        return p
    }
}

struct TestView: View {
    var body: some View {
        ZStack {
            Color.white
            BendedCornerShape(
                radius: 28,
                bendAmount: 1.0,
                absoluteCutoutCenter: CGPoint(x: 8, y: 8),
                cutoutRadius: 13,
                frameOffset: CGPoint(x: 0, y: 0)
            )
            .fill(Color.blue.opacity(0.3))
            
            BendedCornerShape(
                radius: 28,
                bendAmount: 1.0,
                absoluteCutoutCenter: CGPoint(x: 8, y: 8),
                cutoutRadius: 13,
                frameOffset: CGPoint(x: 0, y: 0)
            )
            .strokeBorder(Color.red, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 200, height: 100)
    }
}

let view = NSHostingView(rootView: TestView())
view.frame = CGRect(x: 0, y: 0, width: 200, height: 100)

let bitmapRep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
view.cacheDisplay(in: view.bounds, to: bitmapRep)
let data = bitmapRep.representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: "scratch/test.png"))
print("Saved PNG")
