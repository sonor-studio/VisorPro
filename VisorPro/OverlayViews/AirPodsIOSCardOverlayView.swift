import SwiftUI

struct AirPodsIOSCardOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @EnvironmentObject var overlayState: OverlayStateRelay
    @Environment(\.colorScheme) var colorScheme
    @State private var isCloseHovered: Bool = false
    
    var isPreview: Bool = false
    var previewLeftBattery: Int = 75
    var previewLeftCharging: Bool = true
    var previewRightBattery: Int = 75
    var previewRightCharging: Bool = true
    var previewCaseBattery: Int = 49
    var previewCaseCharging: Bool = false
    
    private var leftBattery: Int { isPreview ? previewLeftBattery : overlayState.airpodsLeftBattery }
    private var leftCharging: Bool { isPreview ? previewLeftCharging : overlayState.airpodsLeftCharging }
    private var rightBattery: Int { isPreview ? previewRightBattery : overlayState.airpodsRightBattery }
    private var rightCharging: Bool { isPreview ? previewRightCharging : overlayState.airpodsRightCharging }
    private var caseBattery: Int { isPreview ? previewCaseBattery : overlayState.airpodsCaseBattery }
    private var caseCharging: Bool { isPreview ? previewCaseCharging : overlayState.airpodsCaseCharging }
    
    private var deviceTitle: String {
        if isPreview {
            return "Jathin's AirPods Pro"
        }
        let name = overlayState.airpodsDeviceName
        if !name.isEmpty && name != "AirPods" {
            return name
        }
        let custom = AirPodsBatteryManager.shared.getCustomAirPodsName()
        return custom.isEmpty ? "AirPods" : custom
    }
    
    private var earbudsBattery: Int {
        if leftBattery > 0 && rightBattery > 0 {
            return (leftBattery + rightBattery) / 2
        }
        return max(leftBattery, rightBattery)
    }
    
    private var isAnyEarbudCharging: Bool {
        leftCharging || rightCharging
    }
    
    var body: some View {
        let isDark = colorScheme == .dark
        
        ZStack {
            // Card Content
            VStack(spacing: 0) {
                // Header: Title & Close Button
                ZStack(alignment: .trailing) {
                    // Centered Device Name
                    HStack {
                        Spacer()
                        Text(deviceTitle)
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.horizontal, 36)
                        Spacer()
                    }
                    
                    // Close button in top right
                    Button {
                        if isPreview {
                            NotificationCenter.default.post(name: NSNotification.Name("PreviewDismissTriggered"), object: nil)
                        } else {
                            MediaKeyManager.shared.dismissAirpodsGroupBatteryIndicator()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.secondary.opacity(isCloseHovered ? 0.28 : 0.16))
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .scaleEffect(isCloseHovered ? 1.08 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { h in
                        isCloseHovered = h
                        if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                    .padding(.trailing, 2)
                }
                .padding(.top, 18)
                .padding(.horizontal, 18)
                
                Spacer()
                
                // Visuals: Earbuds and Charging Case
                HStack(spacing: 28) {
                    // Left Column: Earbuds
                    VStack(spacing: 12) {
                        HStack(spacing: 3) {
                            Image(systemName: "airpodpro.left")
                                .font(.system(size: 46))
                                .foregroundColor(.primary)
                            
                            Image(systemName: "airpodpro.right")
                                .font(.system(size: 46))
                                .foregroundColor(.primary)
                        }
                        .frame(height: 56)
                        
                        VStack(spacing: 4) {
                            batteryIconCapsule(percentage: earbudsBattery, isCharging: isAnyEarbudCharging)
                            
                            if abs(leftBattery - rightBattery) > 5 && leftBattery > 0 && rightBattery > 0 {
                                Text("L \(leftBattery)%  R \(rightBattery)%")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("\(earbudsBattery)%")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Right Column: Charging Case
                    VStack(spacing: 12) {
                        ZStack {
                            Image(systemName: "airpodspro.chargingcase.wireless.fill")
                                .font(.system(size: 56))
                                .foregroundColor(.primary)
                            
                            // Center status LED
                            Circle()
                                .fill(caseCharging ? Color(nsColor: .systemGreen) : (caseBattery <= 20 ? Color.orange : Color(nsColor: .systemGreen).opacity(0.85)))
                                .frame(width: 4, height: 4)
                                .offset(y: 2)
                        }
                        .frame(height: 56)
                        
                        VStack(spacing: 4) {
                            batteryIconCapsule(percentage: caseBattery, isCharging: caseCharging)
                            
                            Text("\(caseBattery)%")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
        }
        .frame(width: 340, height: 240)
        .background(
            ZStack {
                AlwaysActiveVisualEffectView(material: .popover, blendingMode: .behindWindow)
                
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(isDark ? Color(white: 0.12).opacity(0.88) : Color(white: 0.98).opacity(0.88))
                
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .strokeBorder(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.06), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .shadow(color: Color.black.opacity(isDark ? 0.38 : 0.16), radius: 24, x: 0, y: 12)
        )
        .onHoverExact { hovering in
            if !isPreview {
                mediaKeyManager.keepAlive(for: "airpodsGroupBattery", isHovering: hovering)
            }
        }
    }
    
    // MARK: - Native iOS Battery Pill Badge
    @ViewBuilder
    private func batteryIconCapsule(percentage: Int, isCharging: Bool) -> some View {
        let fillFraction = max(0.05, min(1.0, Double(percentage) / 100.0))
        let fillColor = percentage <= 20 ? Color.red : Color(nsColor: .systemGreen)
        
        HStack(spacing: 1.5) {
            // Capsule battery outline + level fill + embedded bolt
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .stroke(Color.secondary.opacity(0.4), lineWidth: 1.2)
                    .frame(width: 25, height: 13)
                
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(fillColor)
                    .frame(width: max(2, 22 * fillFraction), height: 10)
                    .padding(.leading, 1.5)
                
                if isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 7.5, weight: .black))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(width: 25, height: 13)
            
            // Terminal nub
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 1.5, height: 4.5)
        }
    }
}
