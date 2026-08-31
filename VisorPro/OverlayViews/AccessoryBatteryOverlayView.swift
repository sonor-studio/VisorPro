import SwiftUI

struct AccessoryBatteryOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @State private var animatedBatteryProgress: CGFloat = 0.0
    @State private var isExpanded: Bool = false
    @State private var hasFinishedChargeAnimation: Bool = false
    
    var isPreview: Bool = false
    var previewPercentage: Int = 65
    var previewIsWarning: Bool = false
    var previewDeviceName: String = "Magic Mouse"
    var previewIsPluggedIn: Bool = false
    
    private var deviceName: String {
        if isPreview { return previewDeviceName }
        return mediaKeyManager.accessoryBatteryDeviceName
    }
    
    private var percentage: Int {
        if isPreview { return previewPercentage }
        return mediaKeyManager.accessoryBatteryPercentage
    }
    
    private var isWarning: Bool {
        if isPreview { return previewIsWarning }
        return mediaKeyManager.accessoryBatteryIsWarning
    }
    
    private var isPluggedIn: Bool {
        if isPreview { return previewIsPluggedIn }
        return mediaKeyManager.accessoryBatteryIsPluggedIn
    }
    
    private var isFullyCharged: Bool {
        percentage == 100
    }
    
    private var batteryColor: Color {
        if isWarning { return .red }
        if percentage <= 20 { return .red }
        if percentage <= 50 { return .yellow }
        return .green
    }
    
    private var deviceIcon: String {
        if isPreview {
            let lower = previewDeviceName.lowercased()
            if lower.contains("mouse") { return "magicmouse.fill" }
            if lower.contains("keyboard") { return "keyboard.fill" }
            if lower.contains("airpod") || lower.contains("headphone") { return "airpodspro" }
            return "headphones"
        }
        return mediaKeyManager.peripheralIcons[deviceName] ?? accessoryIconFromName(deviceName)
    }
    
    private func accessoryIconFromName(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.hasSuffix("(left)") { return "airpodpro.left" }
        if lower.hasSuffix("(right)") { return "airpodpro.right" }
        if lower.hasSuffix("(case)") { return "airpodspro.chargingcase.wireless.fill" }
        if lower.contains("mouse") || lower.contains("mysz") { return "magicmouse.fill" }
        if lower.contains("keyboard") || lower.contains("klawiatura") { return "keyboard.fill" }
        if lower.contains("trackpad") { return "magicmouse.fill" }
        if lower.contains("airpod") { return "airpodspro" }
        return "headphones"
    }
    
    private var batteryIcon: String {
        if percentage >= 85 { return "battery.100" }
        if percentage >= 60 { return "battery.75" }
        if percentage >= 35 { return "battery.50" }
        if percentage >= 15 { return "battery.25" }
        return "battery.0"
    }
    
    private var statusText: String {
        // For multi-component devices, show component type in status line
        if let label = componentLabel {
            if isWarning { return "Low Battery · \(label)" }
            if isFullyCharged { return "Fully Charged · \(label)" }
            if isPluggedIn { return "Charging · \(label)" }
            return "Battery · \(label)"
        }
        if isWarning { return "Low Battery" }
        if isFullyCharged { return "Fully Charged" }
        if isPluggedIn { return "Charging" }
        return "Battery"
    }
    
    /// For AirPods components, returns "Left Earbud", "Right Earbud", or "Case"
    private var componentLabel: String? {
        if deviceName.hasSuffix(" (Left)") { return "Left" }
        if deviceName.hasSuffix(" (Right)") { return "Right" }
        if deviceName.hasSuffix(" (Case)") { return "Case" }
        return nil
    }
    
    /// Device name without the component suffix for cleaner display
    private var baseName: String {
        if deviceName.hasSuffix(" (Left)") { return String(deviceName.dropLast(7)) }
        if deviceName.hasSuffix(" (Right)") { return String(deviceName.dropLast(8)) }
        if deviceName.hasSuffix(" (Case)") { return String(deviceName.dropLast(7)) }
        return deviceName
    }
    
    var body: some View {
        let batPos = MediaKeyManager.shared.getOverlayPosition(for: "batteryOverlayPosition")
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            progress: animatedBatteryProgress,
            barColor: batteryColor,
            fillCenter: false,
            isMuted: !isWarning && !isPluggedIn && !isFullyCharged,
            customWidth: 260,
            customHeight: isFullyCharged ? 56 : 72,
            supportDragGesture: false,
            isExpandable: true,
            expandUpwards: batPos.hasPrefix("bottom"),
            keepAliveId: "accessoryBattery",
            baseContent: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: deviceIcon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(statusText)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        if isFullyCharged && hasFinishedChargeAnimation {
                            MarqueeText(text: baseName, font: .system(size: 13, weight: .bold, design: .rounded), foregroundColor: .primary)
                        } else {
                            AnimatablePercentageText(progress: animatedBatteryProgress, isTopTitle: false, color: .primary, isPluggedIn: isPluggedIn)
                        }
                        
                        if !isFullyCharged {
                            MarqueeText(text: baseName, font: .system(size: 11, weight: .medium, design: .rounded), foregroundColor: .secondary)
                        }
                    }
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16)
            },
            expandedContent: {
                VStack(spacing: 12) {
                    HStack(spacing: 24) {
                        Spacer()
                        
                        VStack(spacing: 6) {
                            Image(systemName: deviceIcon)
                                .font(.system(size: 26))
                                .foregroundColor(.primary)
                                .frame(height: 32)
                            
                            HStack(spacing: 3) {
                                Image(systemName: batteryIcon)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                if isPluggedIn {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(.green)
                                }
                            }
                            
                            Text("\(percentage)%")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .padding(.top, 8)
                }
            }
        )
        .onAppear {
            runAnimation()
        }
        .onChange(of: mediaKeyManager.accessoryBatteryEventId) { _, _ in
            if !isPreview {
                runAnimation()
            }
        }
        .onChange(of: percentage) { _, newValue in
            withAnimation(.easeInOut(duration: 0.8)) {
                animatedBatteryProgress = CGFloat(newValue) / 100.0
            }
        }
    }
    
    private func runAnimation() {
        let targetProgress = CGFloat(percentage) / 100.0
        animatedBatteryProgress = isWarning ? 1.0 : 0.0
        hasFinishedChargeAnimation = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let distance = isWarning ? (1.0 - targetProgress) : targetProgress
            let actualDuration = isWarning ? 1.2 : (1.5 * Double(distance))
            
            let animation: Animation
            if isWarning {
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
