import SwiftUI

struct TimeoutProgressBar: View {
    let trackWidth: CGFloat
    let isHovering: Bool
    let initialDuration: Double
    let hoverOutDuration: Double
    var isPreview: Bool = false
    
    @State private var animatedProgress: CGFloat = 1.0
    @State private var currentHoveringState: Bool = false
    
    var body: some View {
        Rectangle()
            .modifier(TimeoutProgressBarModifier(progress: animatedProgress, trackWidth: trackWidth))
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
                
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    animatedProgress = 1.0
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

struct TimeoutProgressBarModifier: AnimatableModifier {
    var progress: CGFloat
    var trackWidth: CGFloat
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    func body(content: Content) -> some View {
        content.frame(width: trackWidth * max(0, progress))
    }
}
