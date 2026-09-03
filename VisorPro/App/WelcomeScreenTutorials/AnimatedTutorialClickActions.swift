import SwiftUI

struct AnimatedTutorialClickActions: View {
    @State private var isOn = true
    @State private var cursorOffset = CGSize(width: 50, height: 100)
    @State private var cursorScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            UniversalOverlayView(
                isPreview: true,
                isExpanded: .constant(false),
                showProgressBar: true,
                progress: 1.0,
                barColor: isOn ? .mint : .secondary,
                fillCenter: false,
                isMuted: false,
                customWidth: 230,
                supportDragGesture: false,
                isExpandable: false,
                expandUpwards: false,
                disableTimeoutMode: true,
                baseContent: {
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: isOn ? "capslock.fill" : "capslock")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 26, height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keyboard")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                                
                            MarqueeText(text: isOn ? "Caps Lock ON" : "Caps Lock OFF", font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
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
        isOn = true
        cursorOffset = CGSize(width: 0, height: 80)
        
        // Move to overlay
        withAnimation(.easeInOut(duration: 1.0).delay(0.5)) {
            cursorOffset = CGSize(width: 20, height: 10)
        }
        
        // First click (turn off)
        withAnimation(.easeOut(duration: 0.1).delay(1.5)) {
            cursorScale = 0.8
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.spring()) {
                isOn = false
            }
            withAnimation(.easeOut(duration: 0.1)) {
                cursorScale = 1.0
            }
        }
        
        // Move away
        withAnimation(.easeInOut(duration: 1.0).delay(2.5)) {
            cursorOffset = CGSize(width: 80, height: 100)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            runAnimation()
        }
    }
}
