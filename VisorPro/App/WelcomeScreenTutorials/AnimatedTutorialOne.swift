import SwiftUI

struct AnimatedTutorialOne: View {
    @State private var isExpanded = false
    @State private var cursorOffset = CGSize(width: 50, height: 100)
    @State private var cursorScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            UniversalOverlayView(
                isPreview: true,
                isExpanded: $isExpanded,
                showProgressBar: true,
                progress: 0.65,
                barColor: .blue,
                fillCenter: false,
                isMuted: false,
                supportDragGesture: false,
                isExpandable: true,
                expandUpwards: false,
                disableTimeoutMode: true,
                baseContent: {
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 26, height: 24)
                        MarqueeText(text: "MacBook Pro Speakers", font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                        Spacer(minLength: 8)
                        AnimatablePercentageText(progress: 0.65, isTopTitle: true, color: .primary, isPluggedIn: false, customText: "%d%")
                    }
                    .padding(.horizontal, 23)
                },
                expandedContent: {
                    VStack(alignment: .leading, spacing: 4) {
                        MockDeviceRowView(name: "MacBook Pro Speakers", isCurrent: true)
                        MockDeviceRowView(name: "AirPods Pro", isCurrent: false)
                    }
                    .padding(.top, 2)
                    .padding(.horizontal, 11)
                }
            )
            .environmentObject(MediaKeyManager.shared)
            .frame(width: 260)
            .allowsHitTesting(false)

            Image(nsImage: NSCursor.arrow.image)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                .scaleEffect(cursorScale, anchor: .topLeading)
                .offset(cursorOffset)
        }
        .frame(maxWidth: .infinity, minHeight: 130)
        .onAppear {
            runAnimation()
        }
    }
    
    func runAnimation() {
        isExpanded = false
        cursorOffset = CGSize(width: 0, height: 80)
        
        // Move to overlay
        withAnimation(.easeInOut(duration: 1.0).delay(0.5)) {
            cursorOffset = CGSize(width: 40, height: 10)
        }
        
        // First click (expand)
        withAnimation(.easeOut(duration: 0.1).delay(1.5)) {
            cursorScale = 0.8
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.spring()) {
                isExpanded = true
            }
            withAnimation(.easeOut(duration: 0.1)) {
                cursorScale = 1.0
            }
        }
        
        // Second click (collapse)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.1)) {
                cursorScale = 0.8
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) {
            withAnimation(.spring()) {
                isExpanded = false
            }
            withAnimation(.easeOut(duration: 0.1)) {
                cursorScale = 1.0
            }
        }
        
        // Move away
        withAnimation(.easeInOut(duration: 1.0).delay(4.0)) {
            cursorOffset = CGSize(width: 120, height: 100)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
            runAnimation()
        }
    }
}
