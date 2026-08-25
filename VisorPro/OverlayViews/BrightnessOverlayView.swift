import SwiftUI

struct BrightnessOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("brightnessFillCenter") private var brightnessFillCenter: Bool = true
    @AppStorage("brightnessAllowInteractivity") private var brightnessAllowInteractivity: Bool = true
    @State private var animatedBrightnessProgress: CGFloat = 0.0
    var isPreview: Bool = false
    
    private var actualBrightness: Int {
        isPreview ? 75 : mediaKeyManager.currentBrightness
    }
    
    private var iconName: String {
        if actualBrightness == 0 {
            return "sun.min"
        } else if actualBrightness < 33 {
            return "sun.min.fill"
        } else if actualBrightness < 66 {
            return "sun.max"
        } else {
            return "sun.max.fill"
        }
    }
    
    var body: some View {
        let bPos = MediaKeyManager.shared.getOverlayPosition(for: "brightnessOverlayPosition")
        
        UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: .constant(false),
            showProgressBar: true,
            progress: animatedBrightnessProgress,
            barColor: .yellow.opacity(0.85),
            fillCenter: brightnessFillCenter,
            customWidth: 260,
            customHeight: 56,
            supportDragGesture: brightnessAllowInteractivity,
            onDrag: { v in
                mediaKeyManager.setBrightness(to: Int(v * 100))
            },
            isExpandable: false,
            expandUpwards: bPos == "bottom",
            keepAliveId: "brightness",
            disableTimeoutMode: true,
            baseContent: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 24)
                    
                    Text("Display")
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
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    animatedBrightnessProgress = targetProgress
                }
            }
        }
        .onChange(of: actualBrightness) { _, newValue in
            let targetProgress = CGFloat(newValue) / 100.0
            withAnimation(.easeOut(duration: 0.25)) {
                animatedBrightnessProgress = targetProgress
            }
        }
    }
}
