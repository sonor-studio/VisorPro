import SwiftUI

struct AirPodsGroupBatteryOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @EnvironmentObject var overlayState: OverlayStateRelay
    @State private var isExpanded: Bool = false
    
    var isPreview: Bool = false
    var previewLeftBattery: Int = 85
    var previewLeftCharging: Bool = false
    var previewRightBattery: Int = 80
    var previewRightCharging: Bool = false
    var previewCaseBattery: Int = 40
    var previewCaseCharging: Bool = true
    
    private var leftBattery: Int { isPreview ? previewLeftBattery : overlayState.airpodsLeftBattery }
    private var leftCharging: Bool { isPreview ? previewLeftCharging : overlayState.airpodsLeftCharging }
    private var rightBattery: Int { isPreview ? previewRightBattery : overlayState.airpodsRightBattery }
    private var rightCharging: Bool { isPreview ? previewRightCharging : overlayState.airpodsRightCharging }
    private var caseBattery: Int { isPreview ? previewCaseBattery : overlayState.airpodsCaseBattery }
    private var caseCharging: Bool { isPreview ? previewCaseCharging : overlayState.airpodsCaseCharging }
    
    private var overlayColor: Color {
        if mediaKeyManager.overlayColorMode == "custom" {
            let settings = mediaKeyManager.accessorySettings[overlayState.airpodsDeviceName] ?? AccessoryDeviceSettings()
            return OverlayColorManager.shared.parseColor(settings.colorOnCaseOpen, defaultColor: .green)
        } else if mediaKeyManager.overlayColorMode == "monochrome" {
            return .primary
        }
        return .green
    }

    var body: some View {
        let batPos = MediaKeyManager.shared.getOverlayPosition(for: "batteryOverlayPosition")
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: .constant(false),
            showProgressBar: true,
            progress: 1.0,
            hasTimeoutProgress: false,
            timeoutDuration: 6.0,
            timeoutEventId: overlayState.airpodsGroupBatteryTimerId.uuidString,
            barColor: overlayColor,
            fillCenter: false,
            customWidth: 260,
            customHeight: 134,
            customCornerRadius: 28,
            supportDragGesture: false,
            isExpandable: false,
            expandUpwards: batPos.hasPrefix("bottom"),
            keepAliveId: "airpodsGroupBattery",
            disableTimeoutMode: true,
            baseContent: {
                VStack(spacing: 8) {
                    Text(overlayState.airpodsDeviceName)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(.top, 26)
                        
                    HStack(spacing: 24) {
                        Spacer()
                        batteryComponent(icon: "airpodpro.left", percentage: leftBattery, isCharging: leftCharging)
                        batteryComponent(icon: "airpodspro.chargingcase.wireless.fill", percentage: caseBattery, isCharging: caseCharging)
                        batteryComponent(icon: "airpodpro.right", percentage: rightBattery, isCharging: rightCharging)
                        Spacer()
                    }
                    .padding(.bottom, 26)
                }
            },
            expandedContent: { EmptyView() }
        )
        .id(overlayState.airpodsGroupBatteryEventId)
    }
    
    @ViewBuilder
    private func batteryComponent(icon: String, percentage: Int, isCharging: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundColor(.primary)
                .frame(height: 32)
            
            HStack(spacing: 2) {
                if isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: batteryIcon(for: percentage))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Text("\(percentage)%")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.primary)
        }
    }
    
    private func batteryIcon(for percentage: Int) -> String {
        if percentage >= 85 { return "battery.100" }
        if percentage >= 60 { return "battery.75" }
        if percentage >= 35 { return "battery.50" }
        if percentage >= 15 { return "battery.25" }
        return "battery.0"
    }
}
