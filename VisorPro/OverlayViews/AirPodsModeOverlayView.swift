import SwiftUI

struct AirPodsModeOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @EnvironmentObject var overlayState: OverlayStateRelay
    @Environment(\.colorScheme) var colorScheme
    @State private var isExpanded: Bool = false
    @State private var isHoveringRow: Int? = nil
    var isPreview: Bool = false
    
    private var settings: AccessoryDeviceSettings {
        mediaKeyManager.accessorySettings[overlayState.airpodsDeviceName] ?? AccessoryDeviceSettings()
    }
    
    private var customBarColor: Color {
        if mediaKeyManager.overlayColorMode != "custom" {
            return OverlayColorManager.shared.getOverlayColor(for: "colorOnBluetoothConnect", defaultColor: .blue)
        }
        switch overlayState.airPodsModeValue {
        case 1: return settings.colorOnAirPodsOff != "Default" ? OverlayColorManager.shared.parseColor(settings.colorOnAirPodsOff) : .offStateGray
        case 2: return settings.colorOnAirPodsANC != "Default" ? OverlayColorManager.shared.parseColor(settings.colorOnAirPodsANC) : .blue
        case 3: return settings.colorOnAirPodsTransparency != "Default" ? OverlayColorManager.shared.parseColor(settings.colorOnAirPodsTransparency) : .blue
        case 4: return settings.colorOnAirPodsAdaptive != "Default" ? OverlayColorManager.shared.parseColor(settings.colorOnAirPodsAdaptive) : .blue
        default: return .blue
        }
    }
    
    private var airPodsBatteryPercentage: Int? {
        if overlayState.airpodsCurrentBattery > 0 {
            return overlayState.airpodsCurrentBattery
        }
        let devName = overlayState.airpodsDeviceName
        if let direct = overlayState.accessoryBatteryLevels[devName], direct > 0 {
            return direct
        }
        let left = overlayState.airpodsLeftBattery
        let right = overlayState.airpodsRightBattery
        if left > 0 && right > 0 {
            return (left + right) / 2
        } else if left > 0 {
            return left
        } else if right > 0 {
            return right
        }
        if let match = overlayState.accessoryBatteryLevels.first(where: { $0.key.lowercased().contains("airpod") && !$0.key.lowercased().contains("case") && $0.value > 0 }) {
            return match.value
        }
        if overlayState.accessoryBatteryPercentage > 0 {
            return overlayState.accessoryBatteryPercentage
        }
        return isPreview ? 91 : nil
    }
    
    var body: some View {
        let deviceName = overlayState.airpodsDeviceName.isEmpty ? "AirPods" : overlayState.airpodsDeviceName
        let modeText = textForMode(overlayState.airPodsModeValue)
        let modeIcon = iconForMode(overlayState.airPodsModeValue)
        let isSystem = MediaKeyManager.shared.overlayStyle == "system"
        let batPct = airPodsBatteryPercentage
        
        return UniversalOverlayView(
            isPreview: false,
            isExpanded: $isExpanded,
            showProgressBar: true,
            hasTimeoutProgress: true,
            timeoutEventId: overlayState.airPodsModeEventId,
            barColor: customBarColor,
            fillCenter: false,
            isMuted: false,
            customWidth: isSystem ? 216 : 260,
            onRightTap: overlayState.previousAirPodsModeValue != nil ? {
                guard !overlayState.isChangingAirPodsMode else { return }
                if let prevMode = overlayState.previousAirPodsModeValue {
                    mediaKeyManager.setAirPodsMode(prevMode)
                }
            } : nil,
            isExpandable: settings.allowExpansion,
            keepAliveId: "airpodsMode",
            minimalText: modeText,
            minimalIcon: modeIcon,
            systemTitle: deviceName,
            systemSubtitle: modeText,
            systemRightRingValue: batPct,
            systemRightRingProgress: batPct != nil ? (Double(batPct!) / 100.0) : nil,
            systemRightRingColor: batPct != nil ? Color.batteryLevelColor(for: batPct!) : nil,
            baseContent: {
                HStack(alignment: .center, spacing: 12) {
                    iconViewForMode(overlayState.airPodsModeValue, size: 18, color: .primary)
                        .frame(width: 26, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        MarqueeText(
                            text: deviceName,
                            font: .system(size: 13, weight: .semibold, design: .rounded),
                            foregroundColor: .primary
                        )
                        
                        Text(modeText)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer(minLength: 0)
                    
                    if overlayState.previousAirPodsModeValue != nil {
                        ZStack {
                            Circle()
                                .fill(Color.primary.opacity(0.1))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(overlayState.isChangingAirPodsMode ? .secondary : .primary)
                        }
                    }
                }
                .padding(.leading, 23)
                .padding(.trailing, 12)
            },
            expandedContent: {
                VStack(alignment: .leading, spacing: 4) {
                    let allModes = [2, 3, 4, 1]
                    let modes = allModes.filter { mode in
                        if mode == 1 { return mediaKeyManager.notifyOnAirPodsOff }
                        if mode == 2 { return mediaKeyManager.notifyOnAirPodsANC }
                        if mode == 3 { return mediaKeyManager.notifyOnAirPodsTransparency }
                        if mode == 4 { return mediaKeyManager.notifyOnAirPodsAdaptive }
                        return true
                    }
                    let finalModes = modes.isEmpty ? [overlayState.airPodsModeValue] : modes
                    ForEach(finalModes, id: \.self) { mode in
                        let isSelected = overlayState.airPodsModeValue == mode
                        Button(action: {
                            guard !overlayState.isChangingAirPodsMode else { return }
                            mediaKeyManager.setAirPodsMode(mode)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded = false
                            }
                        }) {
                            HStack(spacing: 10) {
                                iconViewForMode(mode, size: 14, color: overlayState.isChangingAirPodsMode ? .secondary : .primary)
                                    .frame(width: 20, alignment: .center)
                                
                                Text(textForMode(mode))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(overlayState.isChangingAirPodsMode ? .secondary : .primary)
                                
                                Spacer()
                                
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(overlayState.isChangingAirPodsMode ? .secondary : OverlayColorManager.shared.getOverlayColor(for: "colorOnBluetoothConnect", defaultColor: .blue))
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isHoveringRow == mode ? Color.primary.opacity(0.08) : Color.clear)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .pointingHandCursor()
                        .onHoverExact { hovering in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if hovering { isHoveringRow = mode }
                                else if isHoveringRow == mode { isHoveringRow = nil }
                            }
                        }
                    }
                }
                .padding(.horizontal, 11)
                .padding(.top, 2)
            }
        )
    }
    
    @ViewBuilder
    private func iconViewForMode(_ mode: Int, size: CGFloat, color: Color) -> some View {
        if mode == 4 {
            // Emulate Adaptive Audio (Person with a star above head)
            ZStack {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.8, weight: .medium))
                    .offset(y: size * 0.1)
                Image(systemName: "sparkles")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .offset(x: size * 0.4, y: -size * 0.4)
            }
            .foregroundColor(color)
        } else {
            Image(systemName: iconForMode(mode))
                .font(.system(size: size, weight: .medium))
                .foregroundColor(color)
        }
    }
    
    private func iconForMode(_ mode: Int) -> String {
        switch mode {
        case 1: return "airpods" // Off
        case 2: return "person.wave.2.fill" // ANC
        case 3: return "person.and.background.dotted" // Transparency
        case 4: return "sparkles" // Adaptive Audio
        default: return "airpods"
        }
    }
    
    private func textForMode(_ mode: Int) -> String {
        switch mode {
        case 1: return "Off"
        case 2: return "Noise Cancellation"
        case 3: return "Transparency"
        case 4: return "Adaptive Audio"
        default: return "Unknown (\(mode))"
        }
    }
}
