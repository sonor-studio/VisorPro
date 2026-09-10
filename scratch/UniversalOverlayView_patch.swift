import SwiftUI

struct BendedCornerShape: InsettableShape {
    var radius: CGFloat
    var bendAmount: CGFloat
    var absoluteCutoutCenter: CGPoint
    var cutoutRadius: CGFloat
    var frameOffset: CGPoint
    
    var insetAmount: CGFloat = 0
    
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(bendAmount, insetAmount) }
        set {
            bendAmount = newValue.first
            insetAmount = newValue.second
        }
    }
    
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
        
        if bendAmount > 0.01 {
            let cx = absoluteCutoutCenter.x - frameOffset.x
            let cy = absoluteCutoutCenter.y - frameOffset.y
            let cr = cutoutRadius + insetAmount
            
            let dxLeft = insetAmount - cx
            let termLeft = cr*cr - dxLeft*dxLeft
            
            let dyTop = insetAmount - cy
            let termTop = cr*cr - dyTop*dyTop
            
            if termLeft > 0 && termTop > 0 {
                let yIntersect = cy + sqrt(termLeft)
                let xIntersect = cx + sqrt(termTop)
                
                let targetY = max(insetAmount + r, yIntersect)
                let targetX = max(insetAmount + r, xIntersect)
                
                let normalLeftY = insetAmount + r
                let normalTopX = insetAmount + r
                
                let currentLeftY = normalLeftY + (targetY - normalLeftY) * bendAmount
                let currentTopX = normalTopX + (targetX - normalTopX) * bendAmount
                
                p.addLine(to: CGPoint(x: insetAmount, y: currentLeftY))
                
                let ctrlX = cx + cr * bendAmount * 0.75
                let ctrlY = cy + cr * bendAmount * 0.75
                
                p.addQuadCurve(to: CGPoint(x: currentTopX, y: insetAmount), control: CGPoint(x: ctrlX, y: ctrlY))
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
