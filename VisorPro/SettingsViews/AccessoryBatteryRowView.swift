import SwiftUI

struct AccessoryBatteryRowView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    let device: String
    let isComponent: Bool
    
    private var titleText: String {
        if isComponent {
            if device.hasSuffix(" (Left)") { return "Left Earbud" }
            if device.hasSuffix(" (Right)") { return "Right Earbud" }
            if device.hasSuffix(" (Case)") { return "Case" }
        }
        return device
    }
    
    var body: some View {
        let deviceIcon = mediaKeyManager.peripheralIcons[device] ?? "bolt.batteryblock.fill"
        let percentage = mediaKeyManager.accessoryBatteryLevels[device]
        let isCharging = mediaKeyManager.accessoryBatteryCharging[device] ?? false
        let isBlocked = mediaKeyManager.accessoryBatteryBlocklist.contains(device)
        
        let subtitleText = isBlocked ? "Tracking disabled" : (percentage != nil ? "Battery: \(percentage!)% \(isCharging ? "⚡️" : "")" : "Tracking enabled")
        
        CustomSettingsRow(
            icon: deviceIcon,
            iconColor: isBlocked ? .gray : .green,
            title: titleText,
            subtitle: subtitleText
        ) {
            Toggle("", isOn: Binding(
                get: { !isBlocked },
                set: { isOn in
                    if isOn {
                        mediaKeyManager.accessoryBatteryBlocklist.removeAll { $0 == device }
                    } else {
                        if !mediaKeyManager.accessoryBatteryBlocklist.contains(device) {
                            mediaKeyManager.accessoryBatteryBlocklist.append(device)
                        }
                    }
                }
            )).labelsHidden()
        }
        .padding(.leading, isComponent ? 30 : 0)
    }
}
