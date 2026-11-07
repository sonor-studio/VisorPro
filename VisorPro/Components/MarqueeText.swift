import SwiftUI

struct MarqueeText: View {
    var text: String
    var font: Font
    var foregroundColor: Color
    var alignment: Alignment = .leading
    
    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var animationId: UUID = UUID()
    
    private var isOverflowing: Bool {
        containerWidth > 0 && textWidth > containerWidth + 1.0
    }
    
    private var effectiveAlignment: Alignment {
        isOverflowing ? .leading : alignment
    }
    
    var body: some View {
        Text(" ")
            .font(font)
            .lineLimit(1)
            .hidden()
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: effectiveAlignment)
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
                        .offset(x: isOverflowing ? offset : 0)
                },
                alignment: effectiveAlignment
            )
            .clipped()
            .id(text)
            .onAppear {
                restartAnimation()
            }
            .onChange(of: text) { _, _ in
                restartAnimation()
            }
            .onDisappear {
                stopAnimation()
            }
    }
    
    private func stopAnimation() {
        animationId = UUID()
    }
    
    private func restartAnimation() {
        stopAnimation()
        
        var t = Transaction(animation: nil)
        t.disablesAnimations = true
        withTransaction(t) {
            offset = 0
        }
        
        guard isOverflowing else { return }
        
        let currentId = UUID()
        animationId = currentId
        
        let distance = textWidth - containerWidth
        let scrollSpeed: Double = 20.0 // points per second (constant linear speed)
        let duration = max(0.6, Double(distance) / scrollSpeed)
        let pauseAtStart: Double = 1.4 // pause duration at start (shows beginning of text)
        let pauseAtEnd: Double = 1.4 // pause duration at end (shows end of text)
        
        func step() {
            guard animationId == currentId else { return }
            
            // 1. Wait at start (offset = 0) so the user can read the beginning
            DispatchQueue.main.asyncAfter(deadline: .now() + pauseAtStart) {
                guard animationId == currentId else { return }
                
                // 2. Linear scroll forward to the end at constant speed
                withAnimation(.linear(duration: duration)) {
                    offset = -distance
                }
                
                // 3. Wait for scroll duration + pauseAtEnd
                DispatchQueue.main.asyncAfter(deadline: .now() + duration + pauseAtEnd) {
                    guard animationId == currentId else { return }
                    
                    // 4. Instantly teleport back to 0 (no backward scrolling)
                    var snapTrans = Transaction(animation: nil)
                    snapTrans.disablesAnimations = true
                    withTransaction(snapTrans) {
                        offset = 0
                    }
                    
                    // 5. Repeat cycle (will pause at start, scroll, etc.)
                    step()
                }
            }
        }
        
        step()
    }
}
