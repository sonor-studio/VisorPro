import SwiftUI

struct BatterySettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @Environment(\.openWindow) private var openWindow
    @AppStorage("batteryOverlayPosition") private var batteryOverlayPosition: String = "top"
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("batteryFillCenter") private var batteryFillCenter: Bool = false
    @AppStorage("batteryAllowExpansion") private var batteryAllowExpansion: Bool = true
    @State private var isAccessoryHistoryExpanded: Bool = false
    @State private var expandedThresholds: Set<UUID> = []
    @State private var isFullyChargedExpanded: Bool = false
    
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
                        
                            HStack(alignment: .center, spacing: 20) {
                                BatteryOverlayView(isWarningMode: false, isPreview: true, previewType: "plugged")
                                    .applyTheme(mediaKeyManager.overlayTheme)
                                
                                BatteryOverlayView(isWarningMode: true, isPreview: true, previewType: "low20")
                                    .applyTheme(mediaKeyManager.overlayTheme)
                            }
                            .scaleEffect(0.85)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 20)
                
                    Divider()
                
                    VStack(alignment: .leading, spacing: 12) {
                        
                    
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
            .padding(.vertical, 20)
        }
        .navigationTitle("Battery")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }

}
