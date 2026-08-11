import SwiftUI

struct KeyboardBrightnessOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("keyboardBrightnessFillCenter") private var keyboardBrightnessFillCenter: Bool = true
    @State private var animatedBrightnessProgress: CGFloat = 0.0
    @State private var isDragging: Bool = false
    @State private var holdTimer: Timer? = nil
    var isPreview: Bool = false
    
    private var actualBrightness: Int {
        isPreview ? 75 : mediaKeyManager.currentKeyboardBrightness
    }
    
    private var iconName: String {
        return "lightbulb.fill"
    }
    
    var body: some View {
        let width: CGFloat = 260
        let height: CGFloat = 56
        let trackPadding: CGFloat = 4
        let innerPadding: CGFloat = 3
        let outerRadius: CGFloat = 28
        let innerRadius: CGFloat = outerRadius - trackPadding
        
        let trackWidth = width - (trackPadding * 2)
        let trackHeight = height - (trackPadding * 2)
        
        ZStack(alignment: .top) {
            ZStack(alignment: .leading) {
                // WARSTWA 1: Baza
                Group {
                    RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.15), lineWidth: innerPadding)
                        .padding(trackPadding)
                }
                .frame(width: width, height: height)
                
                // WARSTWA 2: Pomarańczowy pasek postępu
                Group {
                    if keyboardBrightnessFillCenter {
                        RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                            .fill(Color.orange.opacity(0.85))
                            .padding(trackPadding)
                    } else {
                        RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                            .strokeBorder(Color.orange.opacity(0.85), lineWidth: innerPadding)
                            .padding(trackPadding)
                    }
                }
                .frame(width: width, height: height)
                .mask(
                    HStack(spacing: 0) {
                        Spacer().frame(width: trackPadding)
                        Rectangle()
                            .frame(width: max(0, trackWidth * animatedBrightnessProgress))
                        Spacer(minLength: 0)
                    }
                )
                
                ZStack {
                    Color.clear.background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: innerRadius - innerPadding, style: .continuous))
                    
                    RoundedRectangle(cornerRadius: innerRadius - innerPadding, style: .continuous)
                        .strokeBorder(Color.glassBorder, lineWidth: 1)
                }
                .padding(trackPadding + innerPadding)
                .frame(width: width, height: height)
            }
            .frame(width: width, height: height)
            .contentShape(RoundedRectangle(cornerRadius: innerRadius + trackPadding, style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if isPreview { return }
                        if isDragging {
                            let v = max(0, min(1, value.location.x / width))
                            mediaKeyManager.setKeyboardBrightness(to: Int(v * 100))
                        } else {
                            let moved = abs(value.translation.width) >= 8 || abs(value.translation.height) >= 8
                            if moved {
                                holdTimer?.invalidate()
                                holdTimer = nil
                                isDragging = true
                                let v = max(0, min(1, value.location.x / width))
                                mediaKeyManager.setKeyboardBrightness(to: Int(v * 100))
                            } else if holdTimer == nil {
                                let timer = Timer(timeInterval: 0.2, repeats: false) { _ in
                                    DispatchQueue.main.async {
                                        isDragging = true
                                        let v = max(0, min(1, value.location.x / width))
                                        mediaKeyManager.setKeyboardBrightness(to: Int(v * 100))
                                    }
                                }
                                RunLoop.main.add(timer, forMode: .common)
                                holdTimer = timer
                            }
                        }
                    }
                    .onEnded { value in
                        if isPreview { return }
                        holdTimer?.invalidate()
                        holdTimer = nil
                        isDragging = false
                    }
            )
            
            // WARSTWA 3: Górna warstwa tekst/ikony
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
            .padding(.horizontal, 16 + trackPadding + innerPadding)
            .frame(width: width, height: height)
            .allowsHitTesting(false)
        }
        .background(
            Color.clear.background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: outerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                        .strokeBorder(Color.glassBorder, lineWidth: 1)
                        .opacity(0)
                )
        )
        .frame(width: width, height: height, alignment: .top)
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(20)
        .onHover { hovering in
            if !isPreview {
                mediaKeyManager.keepAlive(for: "keyboardBrightness", isHovering: hovering)
            }
        }
        .applyTheme(mediaKeyManager.overlayTheme)
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
        .onChange(of: actualBrightness) { newValue in
            let targetProgress = CGFloat(newValue) / 100.0
            withAnimation(.easeOut(duration: 0.25)) {
                animatedBrightnessProgress = targetProgress
            }
        }
    }
}
