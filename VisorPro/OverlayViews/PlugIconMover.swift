import SwiftUI

struct PlugIconMover: AnimatableModifier {
    var progress: CGFloat
    var targetProgress: CGFloat
    var width: CGFloat
    var height: CGFloat
    
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(progress, 0) }
        set { progress = newValue.first }
    }
    
    func getPosition(for d: CGFloat, S1: CGFloat, S2: CGFloat, S3: CGFloat, S4: CGFloat, S5: CGFloat) -> CGPoint {
        let r = height / 2
        var x: CGFloat = 0
        var y: CGFloat = 0
        
        if d <= S1 {
            let p = d / S1
            let a = 180.0 + Double(p) * 90.0
            x = r + r * cos(a * .pi / 180)
            y = r + r * sin(a * .pi / 180)
        } else if d <= S1 + S2 {
            let p = (d - S1) / S2
            x = r + p * S2
            y = 0
        } else if d <= S1 + S2 + S3 {
            let p = (d - S1 - S2) / S3
            let a = -90.0 + Double(p) * 180.0
            x = (width - r) + r * cos(a * .pi / 180)
            y = r + r * sin(a * .pi / 180)
        } else if d <= S1 + S2 + S3 + S4 {
            let p = (d - S1 - S2 - S3) / S4
            x = (width - r) - p * S4
            y = height
        } else {
            let p = (d - S1 - S2 - S3 - S4) / S5
            let a = 90.0 + Double(p) * 90.0
            x = r + r * cos(a * .pi / 180)
            y = r + r * sin(a * .pi / 180)
        }
        return CGPoint(x: x, y: y)
    }
    
    func body(content: Content) -> some View {
        let r = height / 2
        let l = width - height
        
        let S1 = .pi * r / 2
        let S2 = l
        let S3 = .pi * r
        let S4 = l
        let S5 = .pi * r / 2
        
        let total = S1 + S2 + S3 + S4 + S5
        
        let safeProgress = max(0, min(1, progress))
        let d = safeProgress * total
        
        let pCenter = getPosition(for: d, S1: S1, S2: S2, S3: S3, S4: S4, S5: S5)
        
        var angle: Double = 0
        if d <= 0 { angle = 270.0 }
        else if d <= S1 { angle = 270.0 + Double(d / S1) * 90.0 }
        else if d <= S1 + S2 { angle = 360.0 }
        else if d <= S1 + S2 + S3 { angle = 360.0 + Double((d - S1 - S2) / S3) * 180.0 }
        else if d <= S1 + S2 + S3 + S4 { angle = 540.0 }
        else if d < total { 
            let p = (d - S1 - S2 - S3 - S4) / S5
            // Zgodnie z prośbą, opóźniamy start rotacji na ostatnim zakręcie jeszcze bardziej.
            // Blokujemy obrót przez pierwsze 70% zakrętu,
            // a przez pozostałe 30% wtyczka wykonuje bardzo ostry, błyskawiczny obrót.
            let delayedP = p < 0.7 ? 0.0 : (p - 0.7) / 0.3
            angle = 540.0 + Double(delayedP) * 90.0 
        }
        else { angle = 630.0 }
        
        // Standardowe znikanie wtyczki:
        var fadeOutEnd = max(0, min(1, targetProgress)) * total
        var fadeOutStart = fadeOutEnd - 120.0
        
        // Zgodnie z prośbą: przy pełnych 100% chcemy, by zniknęła jeszcze PRZED ostatnim zakrętem (S5)
        if targetProgress >= 0.99 {
            fadeOutEnd = total - S5
            fadeOutStart = fadeOutEnd - 60.0
        }
        
        var iconOpacity: Double = 1.0
        if d > fadeOutStart {
            if d >= fadeOutEnd {
                iconOpacity = 0.0
            } else {
                iconOpacity = 1.0 - Double((d - fadeOutStart) / (fadeOutEnd - fadeOutStart))
            }
        }
        
        // Dodajemy stały offset +5.5 na osiach X i Y (trackPadding + innerPadding/2). 
        return content
            .rotationEffect(.degrees(angle))
            .position(x: pCenter.x + 5.5, y: pCenter.y + 5.5)
            .opacity(iconOpacity)
    }
}
