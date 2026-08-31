import SwiftUI

struct RamChartView: View {
    var history: [Double]
    var color: Color
    var unit: String = "%"
    var timeLabel: String = "-1m"
    
    var body: some View {
        GeometryReader { geometry in
            let labelWidth: CGFloat = 28
            let labelHeight: CGFloat = 14
            
            let w = geometry.size.width - labelWidth
            let h = geometry.size.height - labelHeight
            let count = history.count
            
            ZStack(alignment: .topLeading) {
                // Tło i siatka (Grid)
                ForEach([0, 50, 100], id: \.self) { val in
                    let yPos = h - (CGFloat(val) / 100.0 * h)
                    
                    // Pozioma przerywana linia
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: yPos))
                        path.addLine(to: CGPoint(x: w, y: yPos))
                    }
                    .stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    
                    // Etykieta osi Y
                    Text("\(val)\(unit)")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.secondary)
                        .position(x: w + (labelWidth / 2), y: yPos)
                }
                
                // Pionowa linia pomocnicza (Start)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: h))
                }
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                
                // Etykiety osi X
                Text(timeLabel)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.secondary)
                    .position(x: 12, y: h + (labelHeight / 2))
                
                                Text("-30s")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.secondary)
                    .position(x: w / 2, y: h + (labelHeight / 2))
                
                Text("Now")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.primary.opacity(0.8))
                    .position(x: w - 12, y: h + (labelHeight / 2))
                
                // Wykres
                if count > 1 {
                    let step = w / CGFloat(max(1, count - 1))
                    
                    // Wypełnienie (Gradient)
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
                    .fill(LinearGradient(gradient: Gradient(colors: [color.opacity(0.4), color.opacity(0.0)]), startPoint: .top, endPoint: .bottom))
                    
                    // Główna linia wykresu
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
                    
                    // Punkt oznaczający aktualną wartość
                    if let lastValue = history.last {
                        let normalizedValue = max(0, min(100, lastValue)) / 100.0
                        let y = h - (CGFloat(normalizedValue) * h)
                        
                        Circle()
                            .fill(color)
                            .frame(width: 5, height: 5)
                            .position(x: w, y: y)
                    }
                }
            }
        }
    }
}