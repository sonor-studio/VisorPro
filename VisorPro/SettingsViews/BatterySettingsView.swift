import SwiftUI

struct BatterySettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @Environment(\.openWindow) private var openWindow
    @AppStorage("batteryOverlayPosition") private var batteryOverlayPosition: String = "top"
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("batteryFillCenter") private var batteryFillCenter: Bool = false
    @AppStorage("batteryAllowExpansion") private var batteryAllowExpansion: Bool = true
    @State private var isAccessoryHistoryExpanded: Bool = false
    @State private var previewType: String = "plugged"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Battery Module")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Text("Module Configuration")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                        
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "power", iconColor: .green, title: "Enable Battery Module", subtitle: "When disabled, VisorPro completely ignores power and battery state events") {
                            Toggle("", isOn: $mediaKeyManager.enableBattery).labelsHidden()
                        }
                    }
                    .toggleStyle(.switch)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal)

                if mediaKeyManager.enableBattery {
                
                    VStack(alignment: .center) {
                        Text("Preview")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    
                        ZStack {
                            PreviewBackgroundView()
                        
                            BatteryOverlayView(isWarningMode: previewType.hasPrefix("low"), isPreview: true, previewType: previewType).applyTheme(mediaKeyManager.overlayTheme)
                                .scaleEffect(0.85)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 20)
                
                    Divider()
                
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Interactive Preview")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                            .padding(.leading, 4)
                    
                        HStack(spacing: 12) {
                            Button(action: {
                                withAnimation { previewType = "plugged" }
                            }) {
                                Text("Charging")
                                    .font(.system(size: 12, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(previewType == "plugged" ? Color.blue.opacity(0.2) : Color.primary.opacity(0.1))
                                    .foregroundColor(previewType == "plugged" ? .blue : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button(action: {
                                withAnimation { previewType = "unplugged" }
                            }) {
                                Text("Unplugged")
                                    .font(.system(size: 12, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(previewType == "unplugged" ? Color.blue.opacity(0.2) : Color.primary.opacity(0.1))
                                    .foregroundColor(previewType == "unplugged" ? .blue : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(PlainButtonStyle())
                        
                            Button(action: {
                                withAnimation { previewType = "full" }
                            }) {
                                Text("Fully Charged")
                                    .font(.system(size: 12, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(previewType == "full" ? Color.blue.opacity(0.2) : Color.primary.opacity(0.1))
                                    .foregroundColor(previewType == "full" ? .blue : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(PlainButtonStyle())
                        
                            Button(action: {
                                withAnimation { previewType = "low20" }
                            }) {
                                Text("20% Warning")
                                    .font(.system(size: 12, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(previewType == "low20" ? Color.red.opacity(0.2) : Color.primary.opacity(0.1))
                                    .foregroundColor(previewType == "low20" ? .red : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(PlainButtonStyle())
                        
                            Button(action: {
                                withAnimation { previewType = "low10" }
                            }) {
                                Text("10% Warning")
                                    .font(.system(size: 12, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(previewType == "low10" ? Color.red.opacity(0.2) : Color.primary.opacity(0.1))
                                    .foregroundColor(previewType == "low10" ? .red : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                
                    Divider()
                
                    VStack(alignment: .leading, spacing: 12) {
                        Text("MacBook Battery")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .frame(maxWidth: .infinity, alignment: .center)
                        
                    
                        Text("Overlay Triggers")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.top, 10)
                            .padding(.bottom, 4)
                            .padding(.leading, 4)
                    
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "powerplug.fill", iconColor: .green, title: "Plugged into power", subtitle: "Show when connecting the charger") {
                                HStack(spacing: 8) { if mediaKeyManager.notifyOnPlug { SoundPickerControl(selectedSound: $mediaKeyManager.soundOnPlug) }
    Toggle("", isOn: $mediaKeyManager.notifyOnPlug).labelsHidden() }
                       
                                }
                            Divider().padding(.leading, 48)
                            CustomSettingsRow(icon: "powercord", iconColor: .green, title: "Unplugged from power", subtitle: "Show when disconnecting the charger") {
                                HStack(spacing: 8) { if mediaKeyManager.notifyOnUnplug { SoundPickerControl(selectedSound: $mediaKeyManager.soundOnUnplug) }
    Toggle("", isOn: $mediaKeyManager.notifyOnUnplug).labelsHidden() }
                       
                                }
                            Divider().padding(.leading, 48)
                            CustomSettingsRow(icon: "battery.25", iconColor: .orange, title: "Alert at 20%", subtitle: "Low battery warning") {
                                HStack(spacing: 8) { if mediaKeyManager.notifyOn20Percent { SoundPickerControl(selectedSound: $mediaKeyManager.soundOn20Percent) }
                                    Toggle("", isOn: $mediaKeyManager.notifyOn20Percent).labelsHidden() }
                            }
                            Divider().padding(.leading, 48)
                            CustomSettingsRow(icon: "battery.0", iconColor: .red, title: "Alert at 10%", subtitle: "Critical battery warning") {
                                HStack(spacing: 8) { if mediaKeyManager.notifyOn10Percent { SoundPickerControl(selectedSound: $mediaKeyManager.soundOn10Percent) }
                                    Toggle("", isOn: $mediaKeyManager.notifyOn10Percent).labelsHidden() }
                            }
                            Divider().padding(.leading, 48)
                            ForEach($mediaKeyManager.batteryCustomThresholds) { $threshold in
                                CustomSettingsRow(icon: "bell", iconColor: .green, title: "Alert at \(threshold.percentage)%", subtitle: "Custom battery threshold") {
                                    HStack(spacing: 8) {
                                        Stepper(value: $threshold.percentage, in: 1...99, step: 1) {
                                            Text("\(threshold.percentage)%")
                                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                                .foregroundColor(.primary)
                                        }
                                        .frame(width: 80)
                                        
                                        if threshold.isEnabled { SoundPickerControl(selectedSound: $threshold.sound) }
                                        Toggle("", isOn: $threshold.isEnabled).labelsHidden()
                                        
                                        Button(action: {
                                            mediaKeyManager.batteryCustomThresholds.removeAll { $0.id == threshold.id }
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                Divider().padding(.leading, 48)
                            }
                            CustomSettingsRow(icon: "battery.100", iconColor: .green, title: "Fully charged", subtitle: "Show when reaching full charge") {
                                HStack(spacing: 8) { if mediaKeyManager.notifyOn100Percent { SoundPickerControl(selectedSound: $mediaKeyManager.soundOn100Percent) }
    Toggle("", isOn: $mediaKeyManager.notifyOn100Percent).labelsHidden() }
                       
                                }
                                
                            Divider().padding(.leading, 48)
                            
                            Button(action: {
                                withAnimation {
                                    mediaKeyManager.batteryCustomThresholds.append(BatteryThreshold(percentage: 50, sound: "Ping", isEnabled: true))
                                }
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add Custom Alert")
                                        .font(.system(size: 13, weight: .medium))
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .foregroundColor(.blue)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .pointingHandCursor()
                        }
                        .toggleStyle(.switch)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                        )
                    
                        Text("Behavior")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.top, 10)
                            .padding(.bottom, 4)
                            .padding(.leading, 4)
                    
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "arrow.up.left.and.arrow.down.right", iconColor: .green, title: "Allow Expansion", subtitle: "Allow overlay to expand and show detailed status") {
                                Toggle("", isOn: $batteryAllowExpansion).labelsHidden()
                            }
                        }
                        .toggleStyle(.switch)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                        )
                    
                        Text("Visual Style")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.top, 10)
                            .padding(.bottom, 4)
                            .padding(.leading, 4)
                    
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "circle.circle.fill", iconColor: .green, title: "Fill Center", subtitle: "Fills the inside of the overlay with color instead of just the border") {
                                Toggle("", isOn: $batteryFillCenter).labelsHidden()
                            }
                        }
                        .toggleStyle(.switch)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                        )
                    
                        Group {
                            if overlayPositionMode == "custom" {
                            Text("Overlay Position")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.top, 10)
                                .padding(.leading, 4)
                        
                            PositionPickerGroup(selection: $batteryOverlayPosition)
                            }
                        }
                    }
                    .padding(.horizontal)
                
                    Spacer()
            
                } else {
                    DisabledModuleView(icon: "power", title: "Battery Module is Disabled", description: "Turn on the module to configure power and battery overlays.")
                }
}
        }
        .navigationTitle("Battery")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }

}
