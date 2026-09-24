import SwiftUI

struct AccessoryBatteryOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @EnvironmentObject var overlayState: OverlayStateRelay
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
        return overlayState.accessoryBatteryDeviceName
    }
    
    private var percentage: Int {
        if isPreview { return previewPercentage }
        return overlayState.accessoryBatteryPercentage
    }
    
    private var isWarning: Bool {
        if isPreview { return previewIsWarning }
        return overlayState.accessoryBatteryIsWarning
    }
    
    private var isPluggedIn: Bool {
        if isPreview { return previewIsPluggedIn }
        return overlayState.accessoryBatteryIsPluggedIn
    }
    
    private var isFullyCharged: Bool {
        percentage == 100
    }
    
    private var batteryColor: Color {
        if mediaKeyManager.overlayColorMode == "custom" {
            let settings = mediaKeyManager.accessorySettings[baseName] ?? AccessoryDeviceSettings()
            if isFullyCharged {
                if settings.colorOn100Percent != "Default" { return OverlayColorManager.shared.parseColor(settings.colorOn100Percent) }
            } else if isWarning {
                if let thr = settings.customThresholds.first(where: { $0.percentage == percentage }) {
                    if thr.color != "Default" { return OverlayColorManager.shared.parseColor(thr.color) }
                }
            }
        }
        
        // Don't force red for warning mode, rely on actual percentage
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
        return mediaKeyManager.peripheralIcons[deviceName] ?? MediaKeyManager.fallbackIcon(for: deviceName)
    }
    
    private var batteryIcon: String {
        if percentage >= 85 { return "battery.100" }
        if percentage >= 60 { return "battery.75" }
        if percentage >= 35 { return "battery.50" }
        if percentage >= 15 { return "battery.25" }
        return "battery.0"
    }
    
    private var statusText: String {
        var baseStatus = ""
        if overlayState.accessoryIsConnectionEvent && !isPreview {
            baseStatus = overlayState.accessoryConnectionIsConnected ? "Connected" : "Disconnected"
        } else {
            if isWarning { baseStatus = "Battery Alert" }
            else if isFullyCharged { baseStatus = "Fully Charged" }
            else if isPluggedIn { baseStatus = "Charging" }
            else { baseStatus = "Unplugged" }
        }
        
        // For multi-component devices, show component type in status line
        if let label = componentLabel {
            return "\(baseStatus) · \(label)"
        }
        return baseStatus
    }
    
    /// For AirPods components, returns "Left Earbud", "Right Earbud", or "Case"
    private var componentLabel: String? {
        if deviceName.hasSuffix(" (Left & Right)") { return "Left & Right" }
        if deviceName.hasSuffix(" (Left)") { return "Left" }
        if deviceName.hasSuffix(" (Right)") { return "Right" }
        if deviceName.hasSuffix(" (Case)") { return "Case" }
        return nil
    }
    
    /// Device name without the component suffix for cleaner display
    private var baseName: String {
        if deviceName.hasSuffix(" (Left & Right)") { return String(deviceName.dropLast(15)) }
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
            customHeight: 56,
            supportDragGesture: false,
            isExpandable: true,
            expandUpwards: batPos.hasPrefix("bottom"),
            keepAliveId: "accessoryBattery",
            disableTimeoutMode: true,
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
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        
                        MarqueeText(text: baseName, font: .system(size: 13, weight: .semibold, design: .rounded), foregroundColor: .primary)
                    }
                    Spacer(minLength: 8)
                    
                    if !isFullyCharged {
                        AnimatablePercentageText(progress: animatedBatteryProgress, isTopTitle: true, color: .primary, isPluggedIn: isPluggedIn, customText: "%d%")
                    }
                }
                .padding(.leading, 23)
                .padding(.trailing, 23)
                .frame(maxWidth: .infinity, alignment: .leading)
            },
            expandedContent: {
                VStack(spacing: 12) {
                    if let _ = componentLabel {
                        HStack(spacing: 24) {
                            Spacer()
                            
                            let components = ["Left", "Case", "Right"]
                            ForEach(components, id: \.self) { suffix in
                                if let data = getComponentBattery(suffix: suffix) {
                                    let isTrigger = (componentLabel == suffix) || (componentLabel == "Left & Right" && (suffix == "Left" || suffix == "Right"))
                                    
                                    VStack(spacing: 6) {
                                        Image(systemName: self.iconFor(suffix: suffix))
                                            .font(.system(size: 26))
                                            .foregroundColor(isTrigger ? batteryColor : .primary)
                                            .frame(height: 32)
                                        
                                        HStack(spacing: 3) {
                                            if data.isCharging {
                                                Image(systemName: "bolt.fill")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(isTrigger ? batteryColor : .secondary)
                                            } else {
                                                Image(systemName: self.batteryIcon(for: data.percentage))
                                                    .font(.system(size: 10))
                                                    .foregroundColor(isTrigger ? batteryColor : .secondary)
                                            }
                                        }
                                        
                                        Text("\(data.percentage)%")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(isTrigger ? batteryColor : .primary)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .padding(.top, 8)
                    } else {
                        HStack(spacing: 24) {
                            Spacer()
                            
                            VStack(spacing: 6) {
                                Image(systemName: deviceIcon)
                                    .font(.system(size: 26))
                                    .foregroundColor(.primary)
                                    .frame(height: 32)
                                
                                HStack(spacing: 3) {
                                    if isPluggedIn {
                                        Image(systemName: "bolt.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    } else {
                                        Image(systemName: batteryIcon)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
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
            }
        )
        .onAppear {
            runAnimation()
        }
        .onChange(of: overlayState.accessoryBatteryEventId) { _, _ in
            if !isPreview {
                runAnimation()
            }
        }
        .onChange(of: percentage) { _, newValue in
            withAnimation(.easeInOut(duration: 0.8)) {
                animatedBatteryProgress = CGFloat(newValue) / 100.0
            }
        }
        .id(overlayState.accessoryBatteryEventId)
    }
    
    private var isIncreasing: Bool {
        if isPreview { return false }
        return overlayState.accessoryBatteryIsIncreasing
    }
    
    private func getComponentBattery(suffix: String) -> (percentage: Int, isCharging: Bool)? {
        let fullName = "\(baseName) (\(suffix))"
        guard let pct = mediaKeyManager.accessoryBatteryLevels[fullName] else {
            if baseName == overlayState.airpodsDeviceName {
                if suffix == "Left" && overlayState.airpodsLeftBattery > 0 { return (overlayState.airpodsLeftBattery, overlayState.airpodsLeftCharging) }
                if suffix == "Right" && overlayState.airpodsRightBattery > 0 { return (overlayState.airpodsRightBattery, overlayState.airpodsRightCharging) }
                if suffix == "Case" && overlayState.airpodsCaseBattery > 0 { return (overlayState.airpodsCaseBattery, overlayState.airpodsCaseCharging) }
            }
            return nil
        }
        
        let isCharging = (baseName == overlayState.airpodsDeviceName) ? {
            if suffix == "Left" { return overlayState.airpodsLeftCharging }
            if suffix == "Right" { return overlayState.airpodsRightCharging }
            return overlayState.airpodsCaseCharging
        }() : (mediaKeyManager.accessoryBatteryCharging[fullName] == true)
        
        return (pct, isCharging)
    }
    
    private func batteryIcon(for pct: Int) -> String {
        if pct >= 85 { return "battery.100" }
        if pct >= 60 { return "battery.75" }
        if pct >= 35 { return "battery.50" }
        if pct >= 15 { return "battery.25" }
        return "battery.0"
    }
    
    private func iconFor(suffix: String) -> String {
        if suffix == "Left" { return "airpodpro.left" }
        if suffix == "Right" { return "airpodpro.right" }
        return "airpodspro.chargingcase.wireless.fill"
    }
    
    private func runAnimation() {
        let targetProgress = CGFloat(percentage) / 100.0
        animatedBatteryProgress = isIncreasing ? 0.0 : 1.0
        hasFinishedChargeAnimation = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let distance = isIncreasing ? targetProgress : (1.0 - targetProgress)
            let actualDuration = isWarning ? 1.2 : (1.5 * Double(distance))
            
            var animation: Animation
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
