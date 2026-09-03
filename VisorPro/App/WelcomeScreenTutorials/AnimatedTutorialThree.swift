import SwiftUI

struct AnimatedTutorialThree: View {
    @State private var progress: CGFloat = 1.0
    @State private var opacity: Double = 0.0
    @State private var scale: CGFloat = 0.9

    var body: some View {
        ZStack {
            UniversalOverlayView(
                isPreview: true,
                isExpanded: .constant(false),
                showProgressBar: true,
                progress: progress,
                barColor: .indigo,
                fillCenter: false,
                isMuted: false,
                customWidth: 230,
                supportDragGesture: false,
                isExpandable: false,
                expandUpwards: false,
                disableTimeoutMode: true,
                baseContent: {
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: "airpodspro")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 26, height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bluetooth Connected")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                                
                            MarqueeText(text: "AirPods Pro", font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                        }
                        Spacer(minLength: 8)
                    }
                    .padding(.horizontal, 23)
                },
                expandedContent: { EmptyView() }
            )
            .environmentObject(MediaKeyManager.shared)
            .frame(width: 230)
            .allowsHitTesting(false)
            .opacity(opacity)
            .scaleEffect(scale)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .onAppear {
            runAnimation()
        }
    }
    
    func runAnimation() {
        withAnimation(nil) {
            progress = 1.0
            opacity = 0.0
            scale = 0.9
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.5)) {
            opacity = 1.0
            scale = 1.0
        }
        
        withAnimation(.linear(duration: 2.0).delay(0.9)) {
            progress = 0.0
        }
        
        withAnimation(.easeIn(duration: 0.2).delay(3.0)) {
            opacity = 0.0
            scale = 0.9
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            runAnimation()
        }
    }
}
