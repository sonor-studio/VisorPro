import SwiftUI

enum MarqueeState {
    case idle
    case scrolling
}

struct MarqueeText: View {
    var text: String
    var font: Font
    var foregroundColor: Color
    var alignment: Alignment = .leading
    
    @State private var marqueeState: MarqueeState = .idle
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var timer: Timer? = nil
    @State private var animationId: UUID = UUID()
    
    var body: some View {
        Text(" ")
            .font(font)
            .lineLimit(1)
            .hidden()
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: alignment)
            .background(
                GeometryReader { geo -> Color in
                    DispatchQueue.main.async {
                        if abs(geo.size.width - containerWidth) > 0.5 {
                            containerWidth = geo.size.width
                            restartAnimation()
                        }
                    }
                    return Color.clear
                }
            )
            .overlay(
                Group {
                    Text(text)
                        .font(font)
                        .foregroundColor(foregroundColor)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .background(
                            GeometryReader { textGeo -> Color in
                                DispatchQueue.main.async {
                                    if abs(textGeo.size.width - textWidth) > 0.5 {
                                        textWidth = textGeo.size.width
                                        restartAnimation()
                                    }
                                }
                                return Color.clear
                            }
                        )
                        .offset(x: marqueeState == .scrolling ? -(textWidth - containerWidth) : 0)
                        .animation(marqueeState == .scrolling ? .linear(duration: Double(max(0, textWidth - containerWidth)) / 20.0) : .none, value: marqueeState)
                },
                alignment: alignment
            )
            .id(text)
            .clipped()
            .onAppear {
                restartAnimation()
            }
            .onChange(of: text) { oldValue, newValue in
                restartAnimation()
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
    }
    
    private func restartAnimation() {
        timer?.invalidate()
        timer = nil
        marqueeState = .idle
        
        let currentId = UUID()
        animationId = currentId
        
        guard textWidth > containerWidth, containerWidth > 0 else {
            return
        }
        
        let distance = textWidth - containerWidth
        let duration = Double(distance) / 20.0
        let totalCycle = duration + 3.0
        
        // Initial start
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard animationId == currentId else { return }
            marqueeState = .scrolling
        }
        
        // Recurring loop
        timer = Timer.scheduledTimer(withTimeInterval: totalCycle, repeats: true) { _ in
            guard animationId == currentId else { return }
            marqueeState = .idle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                guard animationId == currentId else { return }
                marqueeState = .scrolling
            }
        }
    }
}
