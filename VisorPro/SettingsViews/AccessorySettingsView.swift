import SwiftUI

struct AccessorySettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    let deviceName: String
    
    // We use a local state to bind to, and sync it with MediaKeyManager
    @State private var settings: AccessoryDeviceSettings = AccessoryDeviceSettings()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(deviceName)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Text("Module Configuration")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                        
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "power", iconColor: .green, title: "Enable Accessory Tracking", subtitle: "When disabled, VisorPro completely ignores connection events for this accessory") {
                            Toggle("", isOn: $settings.enableOverlay)
                                .labelsHidden()
                                .onChange(of: settings.enableOverlay) { _, _ in saveSettings() }
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                }
                
                if settings.enableOverlay {
                    VStack(alignment: .center) {
                        Text("Preview")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    
                        ZStack {
                            PreviewBackgroundView()
                        
                            HStack(spacing: 20) {
                                BluetoothOverlayView(isPreview: true, previewIsAccessory: true, previewIsConnected: true, previewDeviceName: deviceName)
                                    .applyTheme(mediaKeyManager.overlayTheme)
                                    .scaleEffect(0.85)
                                    
                                BluetoothOverlayView(isPreview: true, previewIsAccessory: true, previewIsConnected: false, previewDeviceName: deviceName)
                                    .applyTheme(mediaKeyManager.overlayTheme)
                                    .scaleEffect(0.85)
                            }
                        }
                        .frame(minHeight: 180)
                        .padding(.horizontal)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    
                    let components = mediaKeyManager.accessoryBatteryHistory.filter { $0.hasPrefix(deviceName) }
                    if components.count > 1 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Components")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                                
                            VStack(spacing: 0) {
                                ForEach(components.indices, id: \.self) { index in
                                    let comp = components[index]
                                    AccessoryBatteryRowView(device: comp, isComponent: comp != deviceName)
                                    if index < components.count - 1 {
                                        Divider().padding(.leading, 40)
                                    }
                                }
                            }
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Overlay Triggers")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                            
                        // 1. Connection Group
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CONNECTION")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.leading, 12)
                            
                            VStack(spacing: 0) {
                                CustomSettingsRow(icon: "link", iconColor: .blue, title: "On Connect", subtitle: "Show overlay and play sound when connected") {
                                    HStack(spacing: 8) {
                                        if settings.notifyOnConnect {
if mediaKeyManager.overlayColorMode == "custom" {
                                                ColorPickerControl(selectedColor: $settings.colorOnConnect)
                                                    .onChange(of: settings.colorOnConnect) { _, _ in saveSettings() }
                                            }
                                            SoundPickerControl(selectedSound: $settings.soundOnConnect)
                                                .onChange(of: settings.soundOnConnect) { _, _ in saveSettings() }
                                        }
                                        Toggle("", isOn: $settings.notifyOnConnect)
                                            .labelsHidden()
                                            .onChange(of: settings.notifyOnConnect) { _, _ in saveSettings() }
                                    }
                                }
                                
                                Divider().padding(.leading, 40)
                                
                                CustomSettingsRow(icon: "link.badge.plus", iconColor: .orange, title: "On Disconnect", subtitle: "Show overlay and play sound when disconnected") {
                                    HStack(spacing: 8) {
                                        if settings.notifyOnDisconnect {

                                            SoundPickerControl(selectedSound: $settings.soundOnDisconnect)
                                                .onChange(of: settings.soundOnDisconnect) { _, _ in saveSettings() }
                                        }
                                        Toggle("", isOn: $settings.notifyOnDisconnect)
                                            .labelsHidden()
                                            .onChange(of: settings.notifyOnDisconnect) { _, _ in saveSettings() }
                                    }
                                }
                                
                                if deviceName.lowercased().contains("airpod") || deviceName.lowercased().contains("beats") {
                                    Divider().padding(.leading, 40)
                                    
                                    CustomSettingsRow(icon: "airpodspro.chargingcase.wireless.fill", iconColor: .blue, title: "On Case Opened", subtitle: "Show battery overlay when case lid is opened") {
                                        HStack(spacing: 8) {
                                            if settings.notifyOnCaseOpen {
if mediaKeyManager.overlayColorMode == "custom" {
                                                ColorPickerControl(selectedColor: $settings.colorOnCaseOpen)
                                                    .onChange(of: settings.colorOnCaseOpen) { _, _ in saveSettings() }
                                            }
                                                SoundPickerControl(selectedSound: $settings.soundOnCaseOpen)
                                                    .onChange(of: settings.soundOnCaseOpen) { _, _ in saveSettings() }
                                            }
                                            Toggle("", isOn: $settings.notifyOnCaseOpen)
                                                .labelsHidden()
                                                .onChange(of: settings.notifyOnCaseOpen) { _, _ in saveSettings() }
                                        }
                                    }
                                }
                            }
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                        }
                        
                        // 2. Battery Group
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BATTERY ALERTS")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.leading, 12)
                                
                            VStack(spacing: 0) {
                                ForEach($settings.customThresholds) { $threshold in
                                    CustomSettingsRow(icon: "bell", iconColor: .green, title: "Alert at \(threshold.percentage)%", subtitle: "Custom battery threshold") {
                                        HStack(spacing: 8) {
                                            Stepper(value: $threshold.percentage, in: 1...99, step: 1) {
                                                Text("\(threshold.percentage)%")
                                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                                    .foregroundColor(.primary)
                                            }
                                            .frame(width: 80)
                                            .onChange(of: threshold.percentage) { _, _ in saveSettings() }
                                            
                                            if threshold.isEnabled {
if mediaKeyManager.overlayColorMode == "custom" {
                                                ColorPickerControl(selectedColor: $threshold.color)
                                                    .onChange(of: threshold.color) { _, _ in saveSettings() }
                                            }
                                                SoundPickerControl(selectedSound: $threshold.sound)
                                                    .onChange(of: threshold.sound) { _, _ in saveSettings() }
                                            }
                                            
                                            Toggle("", isOn: $threshold.isEnabled)
                                                .labelsHidden()
                                                .onChange(of: threshold.isEnabled) { _, _ in saveSettings() }
                                            
                                            Button(action: {
                                                settings.customThresholds.removeAll { $0.id == threshold.id }
                                                saveSettings()
                                            }) {
                                                Image(systemName: "trash")
                                                    .foregroundColor(.red)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    Divider().padding(.leading, 40)
                                }
                                
                                CustomSettingsRow(icon: "battery.100", iconColor: .green, title: "Fully charged", subtitle: "Show when reaching full charge") {
                                    HStack(spacing: 8) {
                                        if settings.notifyOn100Percent {
if mediaKeyManager.overlayColorMode == "custom" {
                                                ColorPickerControl(selectedColor: $settings.colorOn100Percent)
                                                    .onChange(of: settings.colorOn100Percent) { _, _ in saveSettings() }
                                            }
                                            SoundPickerControl(selectedSound: $settings.soundOn100Percent)
                                                .onChange(of: settings.soundOn100Percent) { _, _ in saveSettings() }
                                        }
                                        Toggle("", isOn: $settings.notifyOn100Percent)
                                            .labelsHidden()
                                            .onChange(of: settings.notifyOn100Percent) { _, _ in saveSettings() }
                                    }
                                }
                                
                                Divider().padding(.leading, 40)
                                
                                Button(action: {
                                    withAnimation {
                                        settings.customThresholds.append(BatteryThreshold(percentage: 50, sound: "None", isEnabled: true))
                                        saveSettings()
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
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                        }
                        
                        let lowerName = deviceName.lowercased()
                        if lowerName.contains("airpod") || lowerName.contains("beats") {
                            // 3. Listening Modes Group
                            VStack(alignment: .leading, spacing: 4) {
                                Text("LISTENING MODES")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 12)
                                    
                                VStack(spacing: 0) {
                                    CustomSettingsRow(icon: "earbuds.case.fill", iconColor: .indigo, title: "Noise Cancellation", subtitle: "Show overlay for ANC mode") {
                                        if mediaKeyManager.overlayColorMode == "custom" {
                                            ColorPickerControl(selectedColor: $settings.colorOnAirPodsANC)
                                                    .onChange(of: settings.colorOnAirPodsANC) { _, _ in saveSettings() }
                                        }

                                        Toggle("", isOn: Binding(
                                            get: { mediaKeyManager.notifyOnAirPodsANC },
                                            set: { mediaKeyManager.notifyOnAirPodsANC = $0 }
                                        )).labelsHidden()
                                    }
                                    Divider().padding(.leading, 40)
                                    CustomSettingsRow(icon: "earbuds", iconColor: .indigo, title: "Transparency", subtitle: "Show overlay for transparency mode") {
                                        if mediaKeyManager.overlayColorMode == "custom" {
                                            ColorPickerControl(selectedColor: $settings.colorOnAirPodsTransparency)
                                                    .onChange(of: settings.colorOnAirPodsTransparency) { _, _ in saveSettings() }
                                        }

                                        Toggle("", isOn: Binding(
                                            get: { mediaKeyManager.notifyOnAirPodsTransparency },
                                            set: { mediaKeyManager.notifyOnAirPodsTransparency = $0 }
                                        )).labelsHidden()
                                    }
                                    Divider().padding(.leading, 40)
                                    CustomSettingsRow(icon: "earbuds.case", iconColor: .indigo, title: "Adaptive Audio", subtitle: "Show overlay for adaptive mode") {
                                        if mediaKeyManager.overlayColorMode == "custom" {
                                            ColorPickerControl(selectedColor: $settings.colorOnAirPodsAdaptive)
                                                    .onChange(of: settings.colorOnAirPodsAdaptive) { _, _ in saveSettings() }
                                        }

                                        Toggle("", isOn: Binding(
                                            get: { mediaKeyManager.notifyOnAirPodsAdaptive },
                                            set: { mediaKeyManager.notifyOnAirPodsAdaptive = $0 }
                                        )).labelsHidden()
                                    }
                                }
                                .toggleStyle(.switch)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                            }
                        }
                    }
                }
                
                Button(action: {
                    mediaKeyManager.forgetAccessory(name: deviceName)
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Forget Accessory")
                    }
                    .foregroundColor(.red)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.3), lineWidth: 1))
                .padding(.top, 16)
            }
            .toggleStyle(.switch)
            .padding(24)
        }
        .onAppear {
            self.settings = mediaKeyManager.accessorySettings[deviceName] ?? AccessoryDeviceSettings()
        }
        .onChange(of: deviceName) { _, newDevice in
            self.settings = mediaKeyManager.accessorySettings[newDevice] ?? AccessoryDeviceSettings()
        }
    }
    
    private func saveSettings() {
        var dict = mediaKeyManager.accessorySettings
        dict[deviceName] = settings
        mediaKeyManager.accessorySettings = dict
    }
}
