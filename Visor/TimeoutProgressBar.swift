import SwiftUI

struct TimeoutProgressBar: View {
    let trackWidth: CGFloat
    let isHovering: Bool
    let initialDuration: Double
    let hoverOutDuration: Double
    
    @State private var animatedProgress: CGFloat = 1.0
    @State private var progressAnimation: Animation? = nil
    
    var body: some View {
        Rectangle()
            .frame(width: trackWidth * animatedProgress)
            .animation(progressAnimation, value: animatedProgress)
            .onChange(of: isHovering) { hovering in
                progressAnimation = hovering ? .easeOut(duration: 0.2) : .linear(duration: hoverOutDuration)
                animatedProgress = hovering ? 1.0 : 0.0
            }
            .onAppear {
                animatedProgress = 1.0
                progressAnimation = .linear(duration: initialDuration)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    animatedProgress = 0.0
                }
            }
    }
}
