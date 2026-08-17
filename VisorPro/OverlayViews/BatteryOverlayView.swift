import SwiftUI

struct BatteryOverlayView: View {
    @AppStorage("batteryUseUniversalStyle") private var batteryUseUniversalStyle: Bool = true
    var isWarningMode: Bool = false
    var isPreview: Bool = false

    var body: some View {
        if batteryUseUniversalStyle {
            UniversalBatteryOverlayView(isWarningMode: isWarningMode, isPreview: isPreview)
        } else {
            LegacyBatteryOverlayView(isWarningMode: isWarningMode, isPreview: isPreview)
        }
    }
}
