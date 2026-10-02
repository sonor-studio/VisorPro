import Foundation
import SwiftUI
import Combine

struct BrightnessOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @EnvironmentObject var overlayState: OverlayStateRelay
    @AppStorage("brightnessFillCenter") private var brightnessFillCenter: Bool = false
    @AppStorage("brightnessAllowInteractivity") private var brightnessAllowInteractivity: Bool = true
    @AppStorage("brightnessAllowExpansion") private var brightnessAllowExpansion: Bool = true
    @State private var animatedBrightnessProgress: CGFloat = 0.0
    
    @StateObject private var displaySettings = DisplaySettingsManager.shared
    @State private var isExpanded: Bool = false
    
    var isPreview: Bool = false
    
    private var actualBrightness: Int {
        isPreview ? 75 : overlayState.currentBrightness
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
            isExpanded: $isExpanded,
            showProgressBar: true,
            progress: animatedBrightnessProgress,
            barColor: OverlayColorManager.shared.getOverlayColor(for: "colorOnBrightness", defaultColor: .yellow),
            fillCenter: brightnessFillCenter,
            customWidth: 260,
            customHeight: 56,
            supportDragGesture: brightnessAllowInteractivity,
            onDrag: { v in
                mediaKeyManager.setBrightness(to: max(0, min(100, Int(v * 100))))
            },
            isExpandable: brightnessAllowExpansion,
            expandUpwards: bPos.hasPrefix("bottom"),
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
                .padding(.leading, 23)
                .padding(.trailing, 23)
                .frame(maxWidth: .infinity, alignment: .leading)
            },
            expandedContent: {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        toggleButton(title: "Dark Mode", icon: "moon.fill", isOn: displaySettings.isDarkMode) {
                            displaySettings.toggleDarkMode()
                        }
                        toggleButton(title: "Night Shift", icon: "sun.and.horizon", isOn: displaySettings.isNightShiftEnabled) {
                            displaySettings.toggleNightShift()
                        }
                        if displaySettings.isTrueToneSupported {
                            toggleButton(title: "True Tone", icon: "sun.max.fill", isOn: displaySettings.isTrueToneEnabled) {
                                displaySettings.toggleTrueTone()
                            }
                        }
                    }
                    .padding(.top, 14)
                    .padding(.bottom, 4)
                    .padding(.horizontal, 16)
                    
                }
                .onAppear {
                    displaySettings.fetchStatuses()
                }
                .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
                    if isExpanded {
                        displaySettings.fetchStatuses()
                    }
                }
            }
        )
        .onAppear {
            if !isPreview {
                BrightnessManager.shared.startPolling()
            }
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
        .onDisappear {
            if !isPreview {
                BrightnessManager.shared.stopPolling()
            }
        }
        .onChange(of: actualBrightness) { _, newValue in
            let targetProgress = CGFloat(newValue) / 100.0
            withAnimation(.easeInOut(duration: 0.2)) {
                animatedBrightnessProgress = targetProgress
            }
        }
    }
    
    @ViewBuilder
    private func toggleButton(title: String, icon: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isOn ? Color.primary.opacity(0.85) : Color.primary.opacity(0.1))
                        .frame(width: 38, height: 38)
                        .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1.5)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isOn ? Color(NSColor.windowBackgroundColor) : .primary.opacity(0.55))
                }
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(isOn ? .primary : .primary.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity)
    }
}
