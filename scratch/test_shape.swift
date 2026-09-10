import Foundation

func testMath() {
    let r: Double = 27.25
    let insetAmount: Double = 0.75
    let cutoutRadius: Double = 13.0
    
    let cx: Double = 8
    let cy: Double = 8
    
    let C2_x = insetAmount + r
    let C2_y = insetAmount + r
    let R2 = r
    
    let dx = C2_x - cx
    let dy = C2_y - cy
    let d = sqrt(dx*dx + dy*dy)
    
    let targetR1 = cutoutRadius + insetAmount
    let gap = d - R2
    let R1 = gap + (targetR1 - gap) * 1.0
    
    let a = (R1*R1 - R2*R2 + d*d) / (2 * d)
    let hSquared = R1*R1 - a*a
    let h_val = sqrt(max(0, hSquared))
    
    let P2_x = cx + a * dx / d
    let P2_y = cy + a * dy / d
    
    let i1_x = P2_x + h_val * dy / d
    let i1_y = P2_y - h_val * dx / d
    
    let i2_x = P2_x - h_val * dy / d
    let i2_y = P2_y + h_val * dx / d
    
    let intA = i1_y > i2_y ? CGPoint(x: i1_x, y: i1_y) : CGPoint(x: i2_x, y: i2_y)
    let intB = i1_y > i2_y ? CGPoint(x: i2_x, y: i2_y) : CGPoint(x: i1_x, y: i1_y)
    
    let angleStart2 = atan2(intA.y - cy, intA.x - cx)
    let angleEnd2 = atan2(intB.y - cy, intB.x - cx)
    
    var sA = angleStart2
    var eA = angleEnd2
    if sA < eA { sA += 2 * .pi }
    
    print("sA: \(sA), eA: \(eA), diff: \(eA - sA)")
    
    let angleStart1 = atan2(0, -r)
    let angleEnd1 = atan2(intA.y - C2_y, intA.x - C2_x)
    print("Arc1 diff: \(angleEnd1 - angleStart1)")
}

testMath()
