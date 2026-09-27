import SwiftUI

struct TimeoutProgressBar: View {
    let trackWidth: CGFloat
    let isHovering: Bool
    let initialDuration: Double
    let hoverOutDuration: Double
    var isPreview: Bool = false
    var hasGlow: Bool = false
    
    @State private var animatedProgress: CGFloat = 1.0
    @State private var currentHoveringState: Bool = false
    
    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .frame(width: trackWidth)
            if hasGlow {
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 24)
            }
        }
        .offset(x: -((trackWidth + 15) * (1.0 - min(1.0, max(0, animatedProgress)))))
        .onChange(of: isHovering) { _, hovering in
            if isPreview { return }
            currentHoveringState = hovering
            let outDuration = max(0.1, hoverOutDuration - 0.2)
            withAnimation(hovering ? .easeOut(duration: 0.2) : .linear(duration: outDuration)) {
                animatedProgress = hovering ? 1.0 : 0.0
            }
        }
        .onAppear {
            currentHoveringState = isHovering
            
            DispatchQueue.main.async {
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    animatedProgress = 1.0
                }
            }
            
            if isPreview { return }
            
            if !isHovering {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    if !currentHoveringState {
                        let adjustedDuration = max(0.1, initialDuration - 0.2)
                        withAnimation(.linear(duration: adjustedDuration)) {
                            animatedProgress = 0.0
                        }
                    }
                }
            }
        }
    }
}
