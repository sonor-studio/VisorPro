import SwiftUI

struct MarqueeText: View {
    var text: String
    var font: Font
    var foregroundColor: Color
    var alignment: Alignment = .leading
    
    @State private var offsetX: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var animationTask: Task<Void, Never>? = nil
    
    var body: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .hidden()
            .frame(maxWidth: .infinity, alignment: alignment)
            .background(
                GeometryReader { geo -> Color in
                    DispatchQueue.main.async {
                        if geo.size.width != containerWidth {
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
                                    if textGeo.size.width != textWidth {
                                        textWidth = textGeo.size.width
                                        restartAnimation()
                                    }
                                }
                                return Color.clear
                            }
                        )
                        .offset(x: offsetX)
                },
                alignment: alignment
            )
            .clipped()
            .onAppear {
                restartAnimation()
            }
            .onChange(of: text) { oldValue, newValue in
                offsetX = 0
                restartAnimation()
            }
            .onDisappear {
                animationTask?.cancel()
                animationTask = nil
            }
    }
    
    private func restartAnimation() {
        animationTask?.cancel()
        
        guard textWidth > containerWidth, containerWidth > 0 else {
            offsetX = 0
            return
        }
        
        let distance = textWidth - containerWidth
        let duration = Double(distance) / 20.0
        
        animationTask = Task {
            await MainActor.run { offsetX = 0 }
            
            while !Task.isCancelled {
                // Wait at the beginning
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if Task.isCancelled { break }
                
                // Animate to the end
                await MainActor.run {
                    withAnimation(.linear(duration: duration)) {
                        offsetX = -distance
                    }
                }
                
                // Wait for the animation to finish + pause at the end
                try? await Task.sleep(nanoseconds: UInt64((duration + 1.5) * 1_000_000_000))
                if Task.isCancelled { break }
                
                // Teleport back to the start
                await MainActor.run {
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        offsetX = 0
                    }
                }
            }
        }
    }
}
