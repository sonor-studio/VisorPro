import SwiftUI

struct BatteryOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("batteryFillCenter") private var batteryFillCenter: Bool = true
    @AppStorage("batteryAllowExpansion") private var batteryAllowExpansion: Bool = true
    @State private var animatedBatteryProgress: CGFloat = 0.0
    @State private var isExpanded: Bool = false
    @State private var hasFinishedChargeAnimation: Bool = false
    
    var isWarningMode: Bool = false
    var isPreview: Bool = false
    var previewType: String = "plugged"
    
    private var actualPercentage: Int {
        if isPreview {
            if previewType == "full" { return 100 }
            if previewType == "low20" { return 20 }
            if previewType == "low10" { return 10 }
            return 82
        }
        return mediaKeyManager.currentBatteryPercentage
    }
    
    private var actualIsPluggedIn: Bool {
        if isPreview {
            if previewType == "unplugged" || previewType.hasPrefix("low") { return false }
            return true
        }
        return mediaKeyManager.isPluggedIn
    }
    
    private var isFullyCharged: Bool {
        if isPreview { return previewType == "full" }
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
            if previewType == "full" { return "You can unplug now" }
            if previewType == "unplugged" { return "About 2h 45m remaining" }
            if previewType.hasPrefix("low") { return "About 25m remaining" }
            return "About 1h 20m to full"
        }
        return mediaKeyManager.batteryTimeRemaining
    }

    var body: some View {
        let batPos = MediaKeyManager.shared.getOverlayPosition(for: "batteryOverlayPosition")
        let isFullyCharged = actualPercentage == 100 || (mediaKeyManager.isEffectivelyFullyCharged && !isPreview)
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            progress: animatedBatteryProgress,
            barColor: batteryColor,
            fillCenter: batteryFillCenter,
            isMuted: !actualIsPluggedIn && !isWarningMode,
            customWidth: 260,
            customHeight: isFullyCharged ? 56 : 72,
            supportDragGesture: false,
            isExpandable: batteryAllowExpansion,
            expandUpwards: batPos.hasPrefix("bottom"),
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
                    

                    let consumers: [(name: String, power: String, icon: NSImage?)] = isPreview ? [
                        ("Final Cut Pro", "45.2", NSImage(named: "PreviewFinalCut")),
                        ("Xcode", "32.5", NSImage(named: "PreviewXcode")),
                        ("WindowServer", "18.1", NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: nil))
                    ] : mediaKeyManager.topBatteryConsumers

                    if (isWarningMode || isPreview) && !consumers.isEmpty {
                        Divider()
                            .padding(.horizontal, 20)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("High Energy Usage")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                            
                            ForEach(0..<consumers.count, id: \.self) { i in
                                let consumer = consumers[i]
                                HStack {
                                    HStack(spacing: 8) {
                                        if let nsImage = consumer.icon {
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
        .onAppear {
            runAnimation()
        }
        .onChange(of: previewType) { _, _ in
            runAnimation()
        }
        .onChange(of: actualPercentage) { _, newValue in
            withAnimation(.easeInOut(duration: 0.8)) {
                animatedBatteryProgress = CGFloat(newValue) / 100.0
            }
        }
    }
    
    private func runAnimation() {
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
}
