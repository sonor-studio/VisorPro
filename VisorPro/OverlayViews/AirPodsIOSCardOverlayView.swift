import SwiftUI
import AppKit
import Combine

// MARK: - Supported AirPods Models with Dedicated 3D Animation Sets
enum AirPodsModel: Int, CaseIterable, Identifiable {
    case pro3 = 0
    case pro2 = 1
    case pro1 = 2
    case gen4 = 3
    case gen3 = 4
    case gen1_2 = 5
    case max = 6
    
    var id: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .pro3: return "AirPods Pro (3rd gen)"
        case .pro2: return "AirPods Pro (2nd gen)"
        case .pro1: return "AirPods Pro (1st gen)"
        case .gen4: return "AirPods 4"
        case .gen3: return "AirPods (3rd gen)"
        case .gen1_2: return "AirPods"
        case .max: return "AirPods Max"
        }
    }
    
    var assetPrefix: String {
        switch self {
        case .pro3: return "AirPodsPro3_Rot"
        case .pro2: return "AirPodsPro2_Rot"
        case .pro1: return "AirPodsPro1_Rot"
        case .gen4: return "AirPods4_Rot"
        case .gen3: return "AirPods3_Rot"
        case .gen1_2: return "AirPods1_Rot"
        case .max: return "AirPodsMax_Rot"
        }
    }
    
    var splitPrefix: String {
        switch self {
        case .pro3: return "AirPodsPro3"
        case .pro2: return "AirPodsPro2"
        case .pro1: return "AirPodsPro1"
        case .gen4: return "AirPods4"
        case .gen3: return "AirPods3"
        case .gen1_2: return "AirPods1"
        case .max: return "AirPodsPro3"
        }
    }
    
    var isMax: Bool {
        self == .max
    }
    
    static func detect(name: String) -> AirPodsModel {
        let lower = name.lowercased()
        if lower.contains("max") {
            return .max
        }
        if lower.contains("pro") {
            if lower.contains("3") || lower.contains("third") {
                return .pro3
            }
            if lower.contains("1") || lower.contains("first") {
                return .pro1
            }
            return .pro2
        }
        if lower.contains("4") {
            return .gen4
        }
        if lower.contains("3") || lower.contains("third") {
            return .gen3
        }
        return .gen1_2
    }
}

struct AirPodsIOSCardOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @EnvironmentObject var overlayState: OverlayStateRelay
    @Environment(\.colorScheme) var colorScheme
    @State private var isCloseHovered: Bool = false
    @State private var previewToggleSplit: Bool = false
    
    // Smooth 2-phase transition state: Combined fades out to blank, then Split fades in (and vice-versa)
    @State private var activeDisplayMode: DisplayMode = .combined
    @State private var contentOpacity: Double = 1.0
    @State private var transitionTask: Task<Void, Never>? = nil
    
    private enum DisplayMode {
        case combined
        case split
    }
    
    var isPreview: Bool = false
    var previewLeftBattery: Int = 99
    var previewLeftCharging: Bool = true
    var previewRightBattery: Int = 99
    var previewRightCharging: Bool = true
    var previewCaseBattery: Int = 70
    var previewCaseCharging: Bool = false
    
    private var leftBattery: Int { isPreview ? (previewToggleSplit ? 99 : previewLeftBattery) : overlayState.airpodsLeftBattery }
    private var leftCharging: Bool { isPreview ? (previewToggleSplit ? false : previewLeftCharging) : overlayState.airpodsLeftCharging }
    private var rightBattery: Int { isPreview ? previewRightBattery : overlayState.airpodsRightBattery }
    private var rightCharging: Bool { isPreview ? previewRightCharging : overlayState.airpodsRightCharging }
    private var caseBattery: Int { isPreview ? previewCaseBattery : overlayState.airpodsCaseBattery }
    private var caseCharging: Bool { isPreview ? previewCaseCharging : overlayState.airpodsCaseCharging }
    
    private var activeModel: AirPodsModel {
        let name = overlayState.airpodsDeviceName
        if !name.isEmpty && name != "AirPods" {
            return AirPodsModel.detect(name: name)
        }
        let custom = AirPodsBatteryManager.shared.getCustomAirPodsName()
        if !custom.isEmpty && custom != "AirPods" {
            return AirPodsModel.detect(name: custom)
        }
        if !name.isEmpty {
            return AirPodsModel.detect(name: name)
        }
        return .pro2
    }
    
    private var deviceTitle: String {
        let name = overlayState.airpodsDeviceName
        if !name.isEmpty && name != "AirPods" {
            return name
        }
        let custom = AirPodsBatteryManager.shared.getCustomAirPodsName()
        if !custom.isEmpty {
            return custom
        }
        return activeModel.displayName
    }
    
    // Check if current device is AirPods Max
    private var isAirPodsMax: Bool {
        activeModel.isMax
    }
    
    // Split mode is active when an earbud is out of the case.
    // In iOS, when an earbud is removed:
    // 1) One earbud stops charging while the other is still charging, or
    // 2) One earbud is disconnected/not detected, or
    // 3) Significant asymmetry (> 18%) when not both actively in case.
    private var isSplitMode: Bool {
        if isPreview {
            return previewToggleSplit
        }
        // If AirPods Max, there are no separate earbuds
        if isAirPodsMax {
            return false
        }
        // If one is disconnected while other is connected
        if (leftBattery > 0 && rightBattery == 0) || (leftBattery == 0 && rightBattery > 0) {
            return true
        }
        // One is charging while the other is not
        if leftBattery > 0 && rightBattery > 0 && (leftCharging != rightCharging) {
            return true
        }
        // Large difference (> 18%)
        if leftBattery > 0 && rightBattery > 0 && abs(leftBattery - rightBattery) > 18 {
            return true
        }
        return false
    }
    
    private var earbudsCombinedBattery: Int {
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
        
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // MARK: - Header (Centered Title with fixed height)
                HStack {
                    Spacer()
                    Text(deviceTitle)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, 48)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .padding(.top, 16)
                
                Spacer(minLength: 8)
                
                // MARK: - 2-Phase Disappearance and Appearance (Fade Out -> Blank -> Fade In)
                ZStack {
                    if activeDisplayMode == .split {
                        splitVisualsView
                    } else {
                        combinedVisualsView
                    }
                }
                .opacity(contentOpacity)
                
                Spacer(minLength: 14)
            }
            
            // MARK: - Close button ('x') - Fixed Top-Trailing Position & Symmetrical Padding
            Button {
                if isPreview {
                    NotificationCenter.default.post(name: NSNotification.Name("PreviewDismissTriggered"), object: nil)
                } else {
                    MediaKeyManager.shared.dismissAirpodsGroupBatteryIndicator()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(isCloseHovered ? 0.14 : 0.07))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(Color.primary.opacity(0.60))
                }
                .scaleEffect(isCloseHovered ? 1.05 : 1.0)
            }
            .buttonStyle(.plain)
            .onHover { h in
                isCloseHovered = h
                if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .frame(width: 318, height: 282)
        .background(
            ZStack {
                AlwaysActiveVisualEffectView(material: .popover, blendingMode: .behindWindow)
                
                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .fill(isDark ? Color(white: 0.13).opacity(0.96) : Color.white.opacity(0.96))
                
                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .strokeBorder(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.05), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
            .shadow(color: Color.black.opacity(isDark ? 0.45 : 0.16), radius: 26, x: 0, y: 12)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // In preview mode, tapping the card triggers the smooth 2-phase transition
            if isPreview {
                previewToggleSplit.toggle()
            }
        }
        .onAppear {
            activeDisplayMode = isSplitMode ? .split : .combined
            contentOpacity = 1.0
        }
        .onChange(of: isSplitMode) { _, newSplit in
            triggerTwoPhaseTransition(targetMode: newSplit ? .split : .combined)
        }
        .onHoverExact { hovering in
            if !isPreview {
                mediaKeyManager.keepAlive(for: "airpodsGroupBattery", isHovering: hovering)
            }
        }
    }
    
    // MARK: - Two-Phase Transition (Fade Out to pure background -> switch -> Fade In)
    private func triggerTwoPhaseTransition(targetMode: DisplayMode) {
        guard targetMode != activeDisplayMode else { return }
        transitionTask?.cancel()
        
        transitionTask = Task { @MainActor in
            // Phase 1: Fade out old content completely
            withAnimation(.easeOut(duration: 0.22)) {
                contentOpacity = 0.0
            }
            
            // Brief pause at 0 opacity (pure white/blank card)
            try? await Task.sleep(nanoseconds: 240_000_000)
            if Task.isCancelled { return }
            
            // Switch content while hidden
            activeDisplayMode = targetMode
            
            // Phase 2: Fade in new content smoothly
            withAnimation(.easeIn(duration: 0.26)) {
                contentOpacity = 1.0
            }
        }
    }
    
    // MARK: - Combined Mode Visuals (360° Rotating Loop + Gauges)
    private var combinedVisualsView: some View {
        VStack(spacing: 12) {
            if isAirPodsMax {
                // AirPods Max 360-degree Rotating Animation (Standalone Headphones)
                AirPodsUnifiedRotatingSequenceView(prefix: activeModel.assetPrefix)
                    .frame(width: 120, height: 96)
                
                // Single Centered Gauge for AirPods Max
                VStack(spacing: 6) {
                    CircularBatteryGaugeView(percentage: earbudsCombinedBattery, isCharging: isAnyEarbudCharging, diameter: 30, strokeWidth: 3.0)
                    
                    Text("\(earbudsCombinedBattery)%")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .frame(width: 120)
            } else {
                // Earbuds + Case in 3D Unison (Prominent, High-Res, Perfectly Balanced)
                AirPodsUnifiedRotatingSequenceView(prefix: activeModel.assetPrefix)
                    .frame(width: 266, height: 96)
                    .clipped()
                
                // Dual Ring Gauges: Mathematically centered under earbuds (left center: 62.0pt) and case (right center: 202.0pt)
                HStack(spacing: 14) {
                    // Earbuds Combined Gauge (visual center at 62.0pt)
                    VStack(spacing: 6) {
                        CircularBatteryGaugeView(percentage: earbudsCombinedBattery, isCharging: isAnyEarbudCharging, diameter: 30, strokeWidth: 3.0)
                        
                        Text("\(earbudsCombinedBattery)%")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .frame(width: 124)
                    
                    // Case Gauge (visual center at 202.0pt)
                    VStack(spacing: 6) {
                        CircularBatteryGaugeView(percentage: caseBattery, isCharging: caseCharging, diameter: 30, strokeWidth: 3.0)
                        
                        Text("\(caseBattery)%")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .frame(width: 128)
                }
                .frame(width: 266)
            }
        }
        .frame(width: 266)
    }
    
    // MARK: - Split Mode Visuals (3 Columns: Left Earbud, Right Earbud, Case)
    private var splitVisualsView: some View {
        HStack(alignment: .top, spacing: 14) {
            // Group of Left & Right Earbuds
            HStack(spacing: 8) {
                // Left Earbud Column
                VStack(spacing: 12) {
                    ZStack {
                        Image("\(activeModel.splitPrefix)_Left")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 72)
                    }
                    .frame(width: 58, height: 96)
                    
                    VStack(spacing: 6) {
                        CircularBatteryGaugeView(percentage: leftBattery, isCharging: leftCharging, diameter: 30, strokeWidth: 3.0)
                        
                        HStack(spacing: 3) {
                            badgeIndicator(text: "L")
                            Text("\(leftBattery)%")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    .frame(width: 58)
                }
                .frame(width: 58)
                
                // Right Earbud Column
                VStack(spacing: 12) {
                    ZStack {
                        Image("\(activeModel.splitPrefix)_Right")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 72)
                    }
                    .frame(width: 58, height: 96)
                    
                    VStack(spacing: 6) {
                        CircularBatteryGaugeView(percentage: rightBattery, isCharging: rightCharging, diameter: 30, strokeWidth: 3.0)
                        
                        HStack(spacing: 3) {
                            badgeIndicator(text: "R")
                            Text("\(rightBattery)%")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    .frame(width: 58)
                }
                .frame(width: 58)
            }
            .frame(width: 124)
            
            // Charging Case Column (128pt wide, identical position and width in both modes)
            VStack(spacing: 12) {
                ZStack {
                    Image("\(activeModel.splitPrefix)_Case")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 90)
                }
                .frame(width: 128, height: 96)
                
                VStack(spacing: 6) {
                    CircularBatteryGaugeView(percentage: caseBattery, isCharging: caseCharging, diameter: 30, strokeWidth: 3.0)
                    
                    HStack(spacing: 3) {
                        Image(systemName: "airpodspro.chargingcase.wireless.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                        Text("\(caseBattery)%")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .frame(width: 128)
            }
            .frame(width: 128)
        }
        .frame(width: 266)
    }
    
    // MARK: - Badge Indicator (L or R)
    @ViewBuilder
    private func badgeIndicator(text: String) -> some View {
        ZStack(alignment: .center) {
            Circle()
                .fill(Color.primary)
                .frame(width: 13, height: 13)
            
            Text(text)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(colorScheme == .dark ? .black : .white)
                .offset(x: text == "L" ? 0.7 : 0.6)
        }
        .frame(width: 13, height: 13)
    }
}

// MARK: - Native SwiftUI 360° Rotating Sequence View (Ultra-Smooth 30 FPS Loop)
struct AirPodsUnifiedRotatingSequenceView: View {
    let prefix: String
    @State private var currentFrame: Int = 0
    private let totalFrames: Int = 180
    
    // Cache arrays of frame image names to eliminate string allocations in the 30 FPS timer loop
    private static var namesCache: [String: [String]] = [:]
    private static func cachedNames(for prefix: String) -> [String] {
        if let existing = namesCache[prefix] { return existing }
        let names = (0..<180).map { String(format: "%@_%03d", prefix, $0) }
        namesCache[prefix] = names
        return names
    }
    
    var body: some View {
        let frameNames = Self.cachedNames(for: prefix)
        Image(frameNames[currentFrame])
            .resizable()
            .scaledToFit()
            .id(prefix)
            .onReceive(Timer.publish(every: 0.0333, on: .main, in: .common).autoconnect()) { _ in
                currentFrame = (currentFrame + 1) % totalFrames
            }
    }
}

// Backwards-compatible aliases
struct AirPodsRotatingSequenceView: View {
    var body: some View {
        AirPodsUnifiedRotatingSequenceView(prefix: "AirPodsPro2_Rot")
    }
}

struct AirPodsMaxRotatingSequenceView: View {
    var body: some View {
        AirPodsUnifiedRotatingSequenceView(prefix: "AirPodsMax_Rot")
    }
}

struct AirPods1RotatingSequenceView: View {
    var body: some View {
        AirPodsUnifiedRotatingSequenceView(prefix: "AirPods1_Rot")
    }
}

// MARK: - Native iOS Battery Ring Gauge
struct CircularBatteryGaugeView: View {
    let percentage: Int
    let isCharging: Bool
    var diameter: CGFloat = 30
    var strokeWidth: CGFloat = 3.0
    
    private var strokeColor: Color {
        if isCharging {
            return Color(nsColor: .systemGreen)
        }
        if percentage <= 20 {
            return Color.red
        }
        return Color(nsColor: .systemGreen)
    }
    
    var body: some View {
        let progress = max(0.03, min(1.0, Double(percentage) / 100.0))
        
        ZStack {
            // Background track
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: strokeWidth)
                .frame(width: diameter, height: diameter)
            
            // Progress ring
            Circle()
                .trim(from: 0.0, to: CGFloat(progress))
                .stroke(strokeColor, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .frame(width: diameter, height: diameter)
                .rotationEffect(.degrees(-90))
            
            // Charging bolt inside center
            if isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(strokeColor)
            }
        }
        .frame(width: diameter, height: diameter)
    }
}
