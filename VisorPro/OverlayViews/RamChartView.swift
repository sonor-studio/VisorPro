import SwiftUI

struct RamChartView: View {
    var history: [Double]
    var color: Color
    
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            let count = history.count
            
            if count > 1 {
                let step = w / CGFloat(max(1, count - 1))
                
                // Background Gradient fill
                Path { path in
                    for (index, value) in history.enumerated() {
                        let normalizedValue = max(0, min(100, value)) / 100.0
                        let x = CGFloat(index) * step
                        let y = h - (CGFloat(normalizedValue) * h)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: 0, y: h))
                    path.closeSubpath()
                }
                .fill(LinearGradient(gradient: Gradient(colors: [color.opacity(0.35), color.opacity(0.02)]), startPoint: .top, endPoint: .bottom))
                
                // Line stroke
                Path { path in
                    for (index, value) in history.enumerated() {
                        let normalizedValue = max(0, min(100, value)) / 100.0
                        let x = CGFloat(index) * step
                        let y = h - (CGFloat(normalizedValue) * h)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
    }
}
