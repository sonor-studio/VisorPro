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
        let deviceIcon = mediaKeyManager.peripheralIcons[device] ?? MediaKeyManager.fallbackIcon(for: device)
        let percentage = mediaKeyManager.accessoryBatteryLevels[device]
        let isCharging = mediaKeyManager.accessoryBatteryCharging[device] ?? false
        let isBlocked = mediaKeyManager.accessoryBatteryBlocklist.contains(device)
        let isBluetooth = mediaKeyManager.isBluetoothAccessory(device)
        let activeColor = isBluetooth 
            ? OverlayColorManager.shared.getOverlayColor(for: "colorOnBluetoothConnect", defaultColor: .indigo)
            : OverlayColorManager.shared.getOverlayColor(for: "colorOnPeripheralConnect", defaultColor: .blue)
        
        let subtitleText = isBlocked ? "Tracking disabled" : (percentage != nil ? "Battery: \(percentage!)% \(isCharging ? "⚡️" : "")" : "Tracking enabled")
        
        CustomSettingsRow(
            icon: deviceIcon,
            iconColor: isBlocked ? .gray : activeColor,
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
    }
}
