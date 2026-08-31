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
                .padding(.horizontal)
                
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
                        CustomSettingsRow(icon: "battery.25", iconColor: .green, title: "Battery drops to 20%", subtitle: "Show low battery warning") {
                            HStack(spacing: 8) { if mediaKeyManager.notifyOn20Percent { SoundPickerControl(selectedSound: $mediaKeyManager.soundOn20Percent) }
Toggle("", isOn: $mediaKeyManager.notifyOn20Percent).labelsHidden() }
                       
                            }
                        Divider().padding(.leading, 48)
                        CustomSettingsRow(icon: "battery.0", iconColor: .green, title: "Battery drops to 10%", subtitle: "Show critical battery warning") {
                            HStack(spacing: 8) { if mediaKeyManager.notifyOn10Percent { SoundPickerControl(selectedSound: $mediaKeyManager.soundOn10Percent) }
Toggle("", isOn: $mediaKeyManager.notifyOn10Percent).labelsHidden() }
                       
                            }
                        Divider().padding(.leading, 48)
                        CustomSettingsRow(icon: "battery.100", iconColor: .green, title: "Fully charged to 100%", subtitle: "Show when reaching full charge") {
                            HStack(spacing: 8) { if mediaKeyManager.notifyOn100Percent { SoundPickerControl(selectedSound: $mediaKeyManager.soundOn100Percent) }
Toggle("", isOn: $mediaKeyManager.notifyOn100Percent).labelsHidden() }
                       
                            }
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
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Accessory Batteries")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                        
                    
                    Text("Behavior")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                        .padding(.leading, 4)
                    
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "magicmouse.fill", iconColor: .green, title: "Enable Accessory Tracking", subtitle: "Track battery levels for connected mice, keyboards, and headphones") {
                            Toggle("", isOn: $mediaKeyManager.enableAccessoryBattery).labelsHidden()
                        }
                    }
                    .toggleStyle(.switch)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
                    
                    if mediaKeyManager.enableAccessoryBattery {
                        Text("Triggers")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.top, 10)
                            .padding(.bottom, 4)
                            .padding(.leading, 4)
                        
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "battery.25", iconColor: .green, title: "Battery drops to 20%", subtitle: "Show low battery warning") {
                                HStack(spacing: 8) { if mediaKeyManager.accessoryNotifyOn20Percent { SoundPickerControl(selectedSound: $mediaKeyManager.accessorySoundOn20Percent) }
                                    Toggle("", isOn: $mediaKeyManager.accessoryNotifyOn20Percent).labelsHidden() }
                            }
                            Divider().padding(.leading, 48)
                            CustomSettingsRow(icon: "battery.0", iconColor: .green, title: "Battery drops to 10%", subtitle: "Show critical battery warning") {
                                HStack(spacing: 8) { if mediaKeyManager.accessoryNotifyOn10Percent { SoundPickerControl(selectedSound: $mediaKeyManager.accessorySoundOn10Percent) }
                                    Toggle("", isOn: $mediaKeyManager.accessoryNotifyOn10Percent).labelsHidden() }
                            }
                            Divider().padding(.leading, 48)
                            CustomSettingsRow(icon: "battery.100", iconColor: .green, title: "Fully charged to 100%", subtitle: "Show when reaching full charge") {
                                HStack(spacing: 8) { if mediaKeyManager.accessoryNotifyOn100Percent { SoundPickerControl(selectedSound: $mediaKeyManager.accessorySoundOn100Percent) }
                                    Toggle("", isOn: $mediaKeyManager.accessoryNotifyOn100Percent).labelsHidden() }
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
                    
                    if !mediaKeyManager.accessoryBatteryHistory.isEmpty && mediaKeyManager.enableAccessoryBattery {
                        let allGroups = groupAccessoryDevices(mediaKeyManager.accessoryBatteryHistory)
                        let displayedGroups = isAccessoryHistoryExpanded ? allGroups : Array(allGroups.prefix(3))
                        
                        Text("Remembered Devices (\(allGroups.count))")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.top, 10)
                            .padding(.leading, 4)
                        
                        VStack(spacing: 0) {
                            ForEach(displayedGroups, id: \.baseName) { group in
                                if group.components.count == 1 && group.components[0] == group.baseName {
                                    AccessoryBatteryRowView(device: group.baseName, isComponent: false)
                                } else {
                                    let allBlocked = group.components.allSatisfy { mediaKeyManager.accessoryBatteryBlocklist.contains($0) }
                                    
                                    CustomSettingsRow(
                                        icon: "earpods",
                                        iconColor: allBlocked ? .gray : .green,
                                        title: group.baseName,
                                        subtitle: allBlocked ? "All components disabled" : "Multi-component device"
                                    ) {
                                        Toggle("", isOn: Binding(
                                            get: { !allBlocked },
                                            set: { isOn in
                                                for comp in group.components {
                                                    if isOn {
                                                        mediaKeyManager.accessoryBatteryBlocklist.removeAll { $0 == comp }
                                                    } else {
                                                        if !mediaKeyManager.accessoryBatteryBlocklist.contains(comp) {
                                                            mediaKeyManager.accessoryBatteryBlocklist.append(comp)
                                                        }
                                                    }
                                                }
                                            }
                                        )).labelsHidden()
                                    }
                                    
                                    ForEach(group.components, id: \.self) { comp in
                                        Divider().padding(.leading, 80)
                                        AccessoryBatteryRowView(device: comp, isComponent: true)
                                    }
                                }
                                
                                if group.baseName != displayedGroups.last?.baseName || (allGroups.count > 3) {
                                    Divider().padding(.leading, 48)
                                }
                            }
                            
                            if allGroups.count > 3 {
                                Button(action: {
                                    withAnimation { isAccessoryHistoryExpanded.toggle() }
                                }) {
                                    Text(isAccessoryHistoryExpanded ? "Show Less" : "Show All (\(mediaKeyManager.accessoryBatteryHistory.count - 3) more)")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.green)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 12)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
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
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .navigationTitle("Battery")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
    
    private func groupAccessoryDevices(_ devices: [String]) -> [(baseName: String, components: [String])] {
        var dict: [String: [String]] = [:]
        var order: [String] = []
        
        for device in devices {
            let baseName: String
            if device.hasSuffix(" (Left)") {
                baseName = String(device.dropLast(7))
            } else if device.hasSuffix(" (Right)") {
                baseName = String(device.dropLast(8))
            } else if device.hasSuffix(" (Case)") {
                baseName = String(device.dropLast(7))
            } else {
                baseName = device
            }
            
            if dict[baseName] == nil {
                dict[baseName] = []
                order.append(baseName)
            }
            dict[baseName]?.append(device)
        }
        return order.map { baseName in
            var components = dict[baseName]!
            if components.count > 1, let idx = components.firstIndex(of: baseName) {
                components.remove(at: idx)
            }
            return (baseName: baseName, components: components)
        }
    }
}
