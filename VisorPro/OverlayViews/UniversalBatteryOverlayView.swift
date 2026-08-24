import SwiftUI

struct UniversalBatteryOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("batteryFillCenter") private var batteryFillCenter: Bool = true
    @AppStorage("batteryAllowExpansion") private var batteryAllowExpansion: Bool = true
    @State private var animatedBatteryProgress: CGFloat = 0.0
    @State private var isExpanded: Bool = false
    @State private var isHovering: Bool = false
    @State private var expandedKeepAliveTimer: Timer? = nil
    @State private var hasFinishedChargeAnimation: Bool = false
    
    var isWarningMode: Bool = false
    var isPreview: Bool = false
    
    private var actualPercentage: Int {
        isPreview ? 82 : mediaKeyManager.currentBatteryPercentage
    }
    
    private var actualIsPluggedIn: Bool {
        isPreview ? true : mediaKeyManager.isPluggedIn
    }
    
    private var isFullyCharged: Bool {
        if isPreview { return false }
        return actualPercentage == 100 || mediaKeyManager.isEffectivelyFullyCharged
    }
    
    private var batteryColor: Color {
        if isWarningMode { return .red }
        if actualPercentage <= 20 {
            return .red
        } else if actualPercentage <= 50 {
            return .yellow
        } else {
            return .green
        }
    }
    
    private var iconName: String {
        if isWarningMode {
            return actualPercentage <= 10 ? "battery.0" : "battery.25"
        }
        if isFullyCharged {
            return "battery.100"
        }
        return actualIsPluggedIn ? "bolt.fill" : (actualPercentage > 50 ? "battery.75" : "battery.50")
    }

    private func mockedTimeRemaining(for percentage: Int) -> String {
        if isPreview {
            return isWarningMode ? "About 2h 15m remaining" : "About 1h 20m to full"
        }
        return mediaKeyManager.batteryTimeRemaining
    }

    var body: some View {
        let batPos = UserDefaults.standard.string(forKey: "batteryOverlayPosition") ?? "top"
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            progress: animatedBatteryProgress,
            barColor: batteryColor,
            fillCenter: batteryFillCenter,
            isMuted: false,
            customWidth: 260,
            customHeight: isFullyCharged ? 56 : 72,
            supportDragGesture: false,
            isExpandable: batteryAllowExpansion,
            expandUpwards: batPos == "bottom",
            keepAliveId: "battery",
            disableTimeoutMode: true,
            baseContent: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if isFullyCharged {
                            Text("Fully Charged")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                            if hasFinishedChargeAnimation {
                                MarqueeText(text: actualPercentage == 100 ? "You can unplug now" : "Charge limit \(mediaKeyManager.chargeLimit)%", font: .system(size: 13, weight: .bold, design: .rounded), foregroundColor: .primary)
                            } else {
                                AnimatablePercentageText(progress: animatedBatteryProgress, isTopTitle: false, color: .primary, isPluggedIn: true)
                            }
                        } else {
                            Text(isWarningMode ? "Low Battery" : (actualIsPluggedIn ? "Charging" : "Unplugged"))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                            AnimatablePercentageText(progress: animatedBatteryProgress, isTopTitle: false, color: .primary, isPluggedIn: actualIsPluggedIn)
                            MarqueeText(text: mockedTimeRemaining(for: actualPercentage), font: .system(size: 11, weight: .medium, design: .rounded), foregroundColor: .secondary)
                        }
                    }
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16)
            },
            expandedContent: {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        VStack(alignment: .center, spacing: 4) {
                            Text((isWarningMode || !actualIsPluggedIn) ? "Condition" : "Power")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Text((isWarningMode || !actualIsPluggedIn) ? mediaKeyManager.batteryCondition : mediaKeyManager.batteryPowerDraw)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        Divider()
                            .frame(height: 24)
                        
                        VStack(alignment: .center, spacing: 4) {
                            Text("Capacity")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Text("\(mediaKeyManager.batteryHealthPercentage)%")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        Divider()
                            .frame(height: 24)
                        
                        VStack(alignment: .center, spacing: 4) {
                            Text("Cycles")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Text("\(mediaKeyManager.batteryCycleCount)")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    
                    if isWarningMode && !mediaKeyManager.topBatteryConsumers.isEmpty {
                        Divider()
                            .padding(.horizontal, 20)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("High Energy Usage")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                            
                            ForEach(0..<mediaKeyManager.topBatteryConsumers.count, id: \.self) { i in
                                let consumer = mediaKeyManager.topBatteryConsumers[i]
                                HStack {
                                    HStack(spacing: 8) {
                                        if let nsImage = mediaKeyManager.getIconForProcess(name: consumer.name) {
                                            Image(nsImage: nsImage)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 14, height: 14)
                                        } else {
                                            Image(systemName: "cpu")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                                .frame(width: 14, height: 14)
                                        }
                                        
                                        Text(consumer.name)
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                    }
                                    Spacer()
                                    Text("\(consumer.power)%")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .fixedSize()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Button(action: {
                        if !isPreview {
                            mediaKeyManager.openBatterySettings()
                        }
                    }) {
                        Text("Open Battery Settings")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 20)
                    
                }
            }
        )

        .onHoverExact { hovering in
            isHovering = hovering
            if !isPreview {
                mediaKeyManager.keepAlive(for: "battery", isHovering: hovering || isExpanded)
            }
        }
        .onAppear {
            let targetProgress = CGFloat(actualPercentage) / 100.0
            animatedBatteryProgress = isWarningMode ? 1.0 : 0.0
            hasFinishedChargeAnimation = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let distance = isWarningMode ? (1.0 - targetProgress) : targetProgress
                let actualDuration = isWarningMode ? 1.2 : (1.5 * Double(distance))
                
                let animation: Animation
                if isWarningMode {
                    animation = Animation.easeOut(duration: actualDuration)
                } else {
                    animation = Animation.timingCurve(0.4, 0.0, 0.2, 1.0, duration: actualDuration)
                }
                
                withAnimation(animation) {
                    animatedBatteryProgress = targetProgress
                }
                
                if isFullyCharged {
                    DispatchQueue.main.asyncAfter(deadline: .now() + actualDuration + 0.1) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            hasFinishedChargeAnimation = true
                        }
                    }
                }
            }
        }
        .onChange(of: actualPercentage) { _, newValue in
            withAnimation(.easeInOut(duration: 0.8)) {
                animatedBatteryProgress = CGFloat(newValue) / 100.0
            }
        }

        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                expandedKeepAliveTimer?.invalidate()
                expandedKeepAliveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    DispatchQueue.main.async {
                        if !isPreview {
                            mediaKeyManager.keepAlive(for: "battery", isHovering: true)
                        }
                    }
                }
            } else {
                expandedKeepAliveTimer?.invalidate()
                if !isPreview {
                    mediaKeyManager.keepAlive(for: "battery", isHovering: isHovering)
                }
            }
        }
        .onDisappear {
            expandedKeepAliveTimer?.invalidate()
            expandedKeepAliveTimer = nil
            if !isPreview {
                mediaKeyManager.keepAlive(for: "battery", isHovering: false)
            }
        }
    }
}
