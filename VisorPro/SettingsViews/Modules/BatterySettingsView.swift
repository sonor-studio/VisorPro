import SwiftUI

struct BatterySettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @Environment(\.openWindow) private var openWindow
    @AppStorage("batteryOverlayPosition") private var batteryOverlayPosition: String = "top"
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("batteryFillCenter") private var batteryFillCenter: Bool = false
    @AppStorage("batteryAllowExpansion") private var batteryAllowExpansion: Bool = true
    @State private var expandedThresholds: Set<UUID> = []
    
    var body: some View {
        ModuleSettingsLayout(
            title: "Battery",
            isEnabled: $mediaKeyManager.enableBattery,
            preview: {
                HStack(alignment: .center, spacing: 20) {
                    BatteryOverlayView(isWarningMode: false, isPreview: true, previewType: "plugged")
                        .applyTheme(mediaKeyManager.overlayTheme)
                        .frame(height: 56, alignment: .center)
                    
                    BatteryOverlayView(isWarningMode: true, isPreview: true, previewType: "low20")
                        .applyTheme(mediaKeyManager.overlayTheme)
                        .frame(height: 56, alignment: .center)
                }
                .fixedSize(horizontal: true, vertical: false)
                .frame(height: 56, alignment: .center)
            },
            popovers: [
                ModulePopover(
                    icon: "bolt.fill",
                    title: "Overlay Triggers",
                    content: AnyView(
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "powerplug.fill", iconColor: .green, title: "Plugged into power", subtitle: "Show when connecting the charger") {
                                HStack(spacing: 8) { 
                                    if mediaKeyManager.notifyOnPlug { SoundPickerControl(selectedSound: $mediaKeyManager.soundOnPlug) }
                                    Toggle("", isOn: $mediaKeyManager.notifyOnPlug).labelsHidden() 
                                }
                            }
                            Divider().padding(.leading, 48)
                            CustomSettingsRow(icon: "powercord", iconColor: .green, title: "Unplugged from power", subtitle: "Show when disconnecting the charger") {
                                HStack(spacing: 8) { 
                                    if mediaKeyManager.notifyOnUnplug { SoundPickerControl(selectedSound: $mediaKeyManager.soundOnUnplug) }
                                    Toggle("", isOn: $mediaKeyManager.notifyOnUnplug).labelsHidden() 
                                }
                            }
                            Divider().padding(.leading, 48)

                            ForEach($mediaKeyManager.batteryCustomThresholds) { $threshold in
                                let isExpanded = expandedThresholds.contains(threshold.id)
                                VStack(spacing: 0) {
                                    CustomSettingsRow(icon: "bell", iconColor: .green, title: "Alert at \(threshold.percentage)%", subtitle: "Custom battery threshold") {
                                        HStack(spacing: 8) {
                                            Stepper(onIncrement: {
                                                let existing = mediaKeyManager.batteryCustomThresholds.filter { $0.id != threshold.id }.map { $0.percentage }
                                                $threshold.wrappedValue.percentage = BatteryThreshold.nextIncrement(current: threshold.percentage, existing: existing)
                                            }, onDecrement: {
                                                let existing = mediaKeyManager.batteryCustomThresholds.filter { $0.id != threshold.id }.map { $0.percentage }
                                                $threshold.wrappedValue.percentage = BatteryThreshold.nextDecrement(current: threshold.percentage, existing: existing)
                                            }) {
                                                Text("\(threshold.percentage)%")
                                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                                    .foregroundColor(.primary)
                                            }
                                            .frame(width: 80)
                                            .disabled(mediaKeyManager.batteryCustomThresholds.count >= 99)
                                            
                                            if threshold.isEnabled { SoundPickerControl(selectedSound: $threshold.sound) }
                                            Toggle("", isOn: $threshold.isEnabled).labelsHidden()
                                            
                                            Button(action: {
                                                mediaKeyManager.batteryCustomThresholds.removeAll { $0.id == threshold.id }
                                            }) {
                                                Image(systemName: "trash")
                                                    .foregroundColor(.red)
                                            }
                                            .buttonStyle(.plain)
                                            
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 14, weight: .semibold))
                                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                                                .foregroundColor(.secondary)
                                                .frame(width: 20, height: 20)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if isExpanded { expandedThresholds.remove(threshold.id) }
                                            else { expandedThresholds.insert(threshold.id) }
                                        }
                                    }
                                    
                                    if isExpanded {
                                        VStack(spacing: 8) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text("Trigger Condition")
                                                        .font(.system(size: 13, weight: .medium))
                                                        .foregroundColor(.primary)
                                                    Text("When should this alert activate?")
                                                        .font(.system(size: 11))
                                                        .foregroundColor(.secondary)
                                                }
                                                Spacer()
                                                Picker("", selection: $threshold.triggerDirection) {
                                                    Text("Any").tag("both")
                                                    Text("Charge").tag("up")
                                                    Text("Drain").tag("down")
                                                }
                                                .pickerStyle(.segmented)
                                                .fixedSize()
                                            }
                                            .padding(.leading, 52)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.bottom, 12)
                                    }
                                }
                                Divider().padding(.leading, 48)
                            }
                            CustomSettingsRow(icon: "battery.100", iconColor: .green, title: "Fully charged", subtitle: "Show when reaching full charge") {
                                HStack(spacing: 8) { 
                                    if mediaKeyManager.notifyOn100Percent { SoundPickerControl(selectedSound: $mediaKeyManager.soundOn100Percent) }
                                    Toggle("", isOn: $mediaKeyManager.notifyOn100Percent).labelsHidden() 
                                }
                            }
                                
                            Divider().padding(.leading, 48)
                            
                            let isMaxReached = mediaKeyManager.batteryCustomThresholds.count >= 99
                            
                            Button(action: {
                                withAnimation {
                                    let existing = mediaKeyManager.batteryCustomThresholds.map { $0.percentage }
                                    let nextPct = BatteryThreshold.nextAvailablePercentage(existing: existing)
                                    mediaKeyManager.batteryCustomThresholds.append(BatteryThreshold(percentage: nextPct, sound: "Ping", isEnabled: true))
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
                                .foregroundColor(isMaxReached ? .gray : .blue)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(isMaxReached)
                            .pointingHandCursor()
                        }
                    )
                ),
                ModulePopover(
                    icon: "slider.horizontal.3",
                    title: "Behavior",
                    content: AnyView(
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "arrow.up.left.and.arrow.down.right", iconColor: .green, title: "Allow Expansion", subtitle: "Allow overlay to expand and show detailed status") {
                                Toggle("", isOn: $batteryAllowExpansion).labelsHidden()
                            }
                        }
                    )
                ),
                ModulePopover(
                    icon: "pip",
                    title: "Overlay Position",
                    show: overlayPositionMode == "custom",
                    content: AnyView(
                        Group {
                            if overlayPositionMode == "custom" {
                                PositionPickerGroup(selection: $batteryOverlayPosition)
                                    .padding(.vertical, 8)
                            } else {
                                CustomSettingsRow(icon: "exclamationmark.triangle.fill", iconColor: .orange, title: "Custom Positioning Disabled", subtitle: "Enable Custom Positioning in General Settings to modify overlay placement.") {
                                    EmptyView()
                                }
                            }
                        }
                    )
                )
            ]
        )
        .navigationTitle("Battery")
    }
}
