import SwiftUI

struct KeyboardBrightnessOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("keyboardBrightnessFillCenter") private var keyboardBrightnessFillCenter: Bool = false
    @AppStorage("keyboardBrightnessAllowInteractivity") private var keyboardBrightnessAllowInteractivity: Bool = true
    @State private var animatedBrightnessProgress: CGFloat = 0.0
    var isPreview: Bool = false
    
    private var actualBrightness: Int {
        isPreview ? 75 : mediaKeyManager.currentKeyboardBrightness
    }
    
    private var iconName: String {
        return "lightbulb.fill"
    }
    
    var body: some View {
        UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: .constant(false),
            showProgressBar: true,
            progress: animatedBrightnessProgress,
            barColor: .orange.opacity(0.85),
            fillCenter: keyboardBrightnessFillCenter,
            customWidth: 260,
            customHeight: 56,
            supportDragGesture: keyboardBrightnessAllowInteractivity,
            onDrag: { v in
                mediaKeyManager.setKeyboardBrightness(to: Int(v * 100))
            },
            isExpandable: false,
            keepAliveId: "keyboardBrightness",
            disableTimeoutMode: true,
            baseContent: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 24)
                    
                    Text("Keyboard")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer(minLength: 8)
                    
                    AnimatablePercentageText(progress: animatedBrightnessProgress, isTopTitle: true, color: .primary, isPluggedIn: false, customText: "%d%")
                }
                .padding(.horizontal, 16)
            },
            expandedContent: {
                EmptyView()
            }
        )

        .onAppear {
            if isPreview {
                animatedBrightnessProgress = 0.1
                withAnimation(.easeInOut(duration: 1.2)) {
                    animatedBrightnessProgress = 0.8
                }
            } else {
                let targetProgress = CGFloat(actualBrightness) / 100.0
                animatedBrightnessProgress = targetProgress
                withAnimation(.easeInOut(duration: 0.2)) {
                    animatedBrightnessProgress = targetProgress
                }
            }
        }
        .onChange(of: actualBrightness) { _, newValue in
            let targetProgress = CGFloat(newValue) / 100.0
            withAnimation(.easeInOut(duration: 0.2)) {
                animatedBrightnessProgress = targetProgress
            }
        }
    }
}

