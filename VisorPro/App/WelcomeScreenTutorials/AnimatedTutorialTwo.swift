import SwiftUI

struct AnimatedTutorialTwo: View {
    @State private var progress: CGFloat = 0.65
    @State private var cursorOffset = CGSize(width: 0, height: 80)
    @State private var cursorScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            UniversalOverlayView(
                isPreview: true,
                isExpanded: .constant(false),
                showProgressBar: true,
                progress: progress,
                barColor: .blue,
                fillCenter: false,
                isMuted: false,
                supportDragGesture: false,
                isExpandable: false,
                expandUpwards: false,
                disableTimeoutMode: true,
                baseContent: {
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: progress > 0.33 ? "speaker.wave.2.fill" : "speaker.wave.1.fill")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 26, height: 24)
                            .animation(nil, value: progress > 0.33)
                        MarqueeText(text: "MacBook Pro Speakers", font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                        Spacer(minLength: 8)
                        AnimatablePercentageText(progress: progress, isTopTitle: true, color: .primary, isPluggedIn: false, customText: "%d%")
                    }
                    .padding(.horizontal, 23)
                },
                expandedContent: { EmptyView() }
            )
            .environmentObject(MediaKeyManager.shared)
            .frame(width: 260)
            .allowsHitTesting(false)

            Image(nsImage: NSCursor.arrow.image)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                .scaleEffect(cursorScale, anchor: .topLeading)
                .offset(cursorOffset)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .onAppear {
            runAnimation()
        }
    }
    
    func runAnimation() {
        withAnimation(nil) {
            progress = 0.65
        }
        cursorOffset = CGSize(width: 40, height: 80)
        
        withAnimation(.easeInOut(duration: 1.0).delay(0.5)) {
            cursorOffset = CGSize(width: 40, height: 10)
        }
        
        withAnimation(.easeOut(duration: 0.1).delay(1.5)) {
            cursorScale = 0.8
        }
        
        withAnimation(.easeInOut(duration: 1.0).delay(1.6)) {
            cursorOffset = CGSize(width: -60, height: 10)
            progress = 0.25
        }
        
        withAnimation(.easeOut(duration: 0.1).delay(2.6)) {
            cursorScale = 1.0
        }
        
        withAnimation(.easeInOut(duration: 1.0).delay(3.0)) {
            cursorOffset = CGSize(width: 60, height: 80)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            runAnimation()
        }
    }
}
