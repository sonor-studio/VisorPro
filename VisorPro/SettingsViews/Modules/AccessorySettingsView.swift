import SwiftUI

struct AccessorySettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    let deviceName: String
    
    // We use a local state to bind to, and sync it with MediaKeyManager
    @State private var settings: AccessoryDeviceSettings = AccessoryDeviceSettings()
    @State private var expandedThresholds: Set<UUID> = []
    @State private var isFullyChargedExpanded: Bool = false
    
    private var isHeadphones: Bool {
        let lower = deviceName.lowercased()
        return lower.contains("airpod") || lower.contains("headphone") || lower.contains("ear") || lower.contains("buds") || lower.contains("headset")
    }
    
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
                    
                    let hasComponents = mediaKeyManager.accessoryBatteryHistory.contains { $0.hasPrefix(deviceName) && $0 != deviceName }
                    VStack(alignment: .leading, spacing: 12) {
                        Text(hasComponents ? "Components Overview" : "Component Overview")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                        
                        if hasComponents {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "airpodpro.left")
                                        .font(.system(size: 40, weight: .light))
                                        .foregroundColor(.primary)
                                        .frame(height: 50)
                                    
                                    VStack(spacing: 4) {
                                        Text("Left")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.secondary)
                                        
                                        if let pct = mediaKeyManager.accessoryBatteryLevels["\(deviceName) (Left)"] {
                                            let isCharging = (OverlayStateRelay.shared.airpodsDeviceName == deviceName) ? OverlayStateRelay.shared.airpodsLeftCharging : (mediaKeyManager.accessoryBatteryCharging["\(deviceName) (Left)"] == true)
                                            if isCharging {
                                                Image(systemName: "bolt.fill").font(.system(size: 11)).foregroundColor(.secondary)
                                            } else {
                                                Image(systemName: batteryIcon(for: pct)).font(.system(size: 11)).foregroundColor(.secondary)
                                            }
                                            Text("\(pct)%")
                                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                                .foregroundColor(.primary)
                                        } else {
                                            Text("--%")
                                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                                .foregroundColor(.secondary.opacity(0.3))
                                        }
                                    }
                                }
                                .frame(width: 90)
                                
                                Spacer()
                                
                                VStack(spacing: 8) {
                                    Image(systemName: "airpodspro.chargingcase.wireless.fill")
                                        .font(.system(size: 44, weight: .light))
                                        .foregroundColor(.primary)
                                        .frame(height: 50)
                                        
                                    VStack(spacing: 4) {
                                        Text("Case")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.secondary)
                                        
                                        if let pct = mediaKeyManager.accessoryBatteryLevels["\(deviceName) (Case)"] {
                                            let isCharging = (OverlayStateRelay.shared.airpodsDeviceName == deviceName) ? OverlayStateRelay.shared.airpodsCaseCharging : (mediaKeyManager.accessoryBatteryCharging["\(deviceName) (Case)"] == true)
                                            if isCharging {
                                                Image(systemName: "bolt.fill").font(.system(size: 11)).foregroundColor(.secondary)
                                            } else {
                                                Image(systemName: batteryIcon(for: pct)).font(.system(size: 11)).foregroundColor(.secondary)
                                            }
                                            Text("\(pct)%")
                                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                                .foregroundColor(.primary)
                                        } else {
                                            Text("--%")
                                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                                .foregroundColor(.secondary.opacity(0.3))
                                        }
                                    }
                                }
                                .frame(width: 90)
                                
                                Spacer()
                                
                                VStack(spacing: 8) {
                                    Image(systemName: "airpodpro.right")
                                        .font(.system(size: 40, weight: .light))
                                        .foregroundColor(.primary)
                                        .frame(height: 50)
                                        
                                    VStack(spacing: 4) {
                                        Text("Right")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.secondary)
                                        
                                        if let pct = mediaKeyManager.accessoryBatteryLevels["\(deviceName) (Right)"] {
                                            let isCharging = (OverlayStateRelay.shared.airpodsDeviceName == deviceName) ? OverlayStateRelay.shared.airpodsRightCharging : (mediaKeyManager.accessoryBatteryCharging["\(deviceName) (Right)"] == true)
                                            if isCharging {
                                                Image(systemName: "bolt.fill").font(.system(size: 11)).foregroundColor(.secondary)
                                            } else {
                                                Image(systemName: batteryIcon(for: pct)).font(.system(size: 11)).foregroundColor(.secondary)
                                            }
                                            Text("\(pct)%")
                                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                                .foregroundColor(.primary)
                                        } else {
                                            Text("--%")
                                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                                .foregroundColor(.secondary.opacity(0.3))
                                        }
                                    }
                                }
                                .frame(width: 90)
                                Spacer()
                            }
                            .padding(.vertical, 32)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                        } else {
                            HStack(spacing: 16) {
                                let iconName = mediaKeyManager.peripheralIcons[deviceName] ?? MediaKeyManager.fallbackIcon(for: deviceName)
                                Image(systemName: iconName)
                                    .font(.system(size: 24, weight: .regular))
                                    .foregroundColor(.primary)
                                    .frame(width: 48, height: 48)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(12)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(deviceName)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    if let pct = mediaKeyManager.accessoryBatteryLevels[deviceName] {
                                        let isCharging = mediaKeyManager.accessoryBatteryCharging[deviceName] == true
                                        HStack(spacing: 4) {
                                            if isCharging {
                                                Image(systemName: "bolt.fill").font(.system(size: 10))
                                                Text("Charging").font(.system(size: 12))
                                            } else {
                                                Image(systemName: batteryIcon(for: pct)).font(.system(size: 10))
                                                Text("Battery").font(.system(size: 12))
                                            }
                                        }
                                        .foregroundColor(.secondary)
                                    } else {
                                        Text("Status unknown")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if let pct = mediaKeyManager.accessoryBatteryLevels[deviceName] {
                                    Text("\(pct)%")
                                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                                        .foregroundColor(.primary)
                                } else {
                                    Text("--%")
                                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                                        .foregroundColor(.secondary.opacity(0.3))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                        }
                    }
                    .padding(.bottom, 16)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Overlay Content")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                            
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "battery.100", iconColor: .green, title: "Show Battery", subtitle: "Display battery percentage in the expanded overlay") {
                                Toggle("", isOn: $settings.showBattery)
                                    .labelsHidden()
                                    .disabled(settings.showBattery && !settings.showDetails)
                                    .onChange(of: settings.showBattery) { _, _ in saveSettings() }
                            }
                            
                            Divider().padding(.leading, 40)
                            
                            CustomSettingsRow(icon: "info.circle", iconColor: .blue, title: "Show Details", subtitle: "Display device details like MAC address and firmware in the expanded overlay") {
                                Toggle("", isOn: $settings.showDetails)
                                    .labelsHidden()
                                    .disabled(settings.showDetails && !settings.showBattery)
                                    .onChange(of: settings.showDetails) { _, _ in saveSettings() }
                            }
                        }
                        .toggleStyle(.switch)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    }
                    .padding(.bottom, 16)
                    
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
                                            if !isHeadphones {
                                                SoundPickerControl(selectedSound: $settings.soundOnConnect)
                                                    .onChange(of: settings.soundOnConnect) { _, _ in saveSettings() }
                                            }
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
                                            if !isHeadphones {
                                                SoundPickerControl(selectedSound: $settings.soundOnDisconnect)
                                                    .onChange(of: settings.soundOnDisconnect) { _, _ in saveSettings() }
                                            }
                                        }
                                        Toggle("", isOn: $settings.notifyOnDisconnect)
                                            .labelsHidden()
                                            .onChange(of: settings.notifyOnDisconnect) { _, _ in saveSettings() }
                                    }
                                }
                                
                                if deviceName.lowercased().contains("airpod") || deviceName.lowercased().contains("beats") {
                                    Divider().padding(.leading, 40)
                                    
                                    CustomSettingsRow(icon: "arrow.right.arrow.left", iconColor: .purple, title: "On Audio Transfer", subtitle: "Show overlay when audio transfers to another device") {
                                        HStack(spacing: 8) {
                                            if settings.notifyOnSmartRouting {
                                                if mediaKeyManager.overlayColorMode == "custom" {
                                                    ColorPickerControl(selectedColor: $settings.colorOnSmartRouting)
                                                        .onChange(of: settings.colorOnSmartRouting) { _, _ in saveSettings() }
                                                }
                                            }
                                            Toggle("", isOn: $settings.notifyOnSmartRouting)
                                                .labelsHidden()
                                                .onChange(of: settings.notifyOnSmartRouting) { _, _ in saveSettings() }
                                        }
                                    }
                                    
                                    Divider().padding(.leading, 40)
                                    
                                    CustomSettingsRow(icon: "airpodspro.chargingcase.wireless.fill", iconColor: .blue, title: "On Case Opened", subtitle: "Show battery overlay when case lid is opened") {
                                        HStack(spacing: 8) {
                                            if mediaKeyManager.overlayColorMode == "custom" {
                                                ColorPickerControl(selectedColor: $settings.colorOnCaseOpen)
                                                    .onChange(of: settings.colorOnCaseOpen) { _, _ in saveSettings() }
                                            }
                                            if settings.notifyOnCaseOpen {
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
                                    let isExpanded = expandedThresholds.contains(threshold.id)
                                    VStack(spacing: 0) {
                                        CustomSettingsRow(icon: "bell", iconColor: .green, title: "Alert at \(threshold.percentage)%", subtitle: "Custom battery threshold") {
                                            HStack(spacing: 8) {
                                                Stepper(onIncrement: {
                                                    let existing = settings.customThresholds.filter { $0.id != threshold.id }.map { $0.percentage }
                                                    $threshold.wrappedValue.percentage = BatteryThreshold.nextIncrement(current: threshold.percentage, existing: existing)
                                                }, onDecrement: {
                                                    let existing = settings.customThresholds.filter { $0.id != threshold.id }.map { $0.percentage }
                                                    $threshold.wrappedValue.percentage = BatteryThreshold.nextDecrement(current: threshold.percentage, existing: existing)
                                                }) {
                                                    Text("\(threshold.percentage)%")
                                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                                        .foregroundColor(.primary)
                                                }
                                                .frame(width: 80)
                                                .disabled(settings.customThresholds.count >= 99)
                                                .onChange(of: threshold.percentage) { _, _ in saveSettings() }
                                                
                                                if threshold.isEnabled {
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
                                                    .onChange(of: threshold.triggerDirection) { _, _ in saveSettings() }
                                                }
                                                .padding(.leading, 52)
                                                
                                                if deviceName.lowercased().contains("airpods") {
                                                    HStack {
                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text("Target Devices")
                                                                .font(.system(size: 13, weight: .medium))
                                                                .foregroundColor(.primary)
                                                            Text("Which components trigger this alert?")
                                                                .font(.system(size: 11))
                                                                .foregroundColor(.secondary)
                                                        }
                                                        Spacer()
                                                        HStack(spacing: 12) {
                                                            Toggle("Left", isOn: $threshold.applyToLeft)
                                                            Toggle("Case", isOn: $threshold.applyToCase)
                                                            Toggle("Right", isOn: $threshold.applyToRight)
                                                        }
                                                        .toggleStyle(.checkbox)
                                                        .font(.system(size: 11))
                                                        .onChange(of: threshold.applyToLeft) { _, _ in saveSettings() }
                                                        .onChange(of: threshold.applyToRight) { _, _ in saveSettings() }
                                                        .onChange(of: threshold.applyToCase) { _, _ in saveSettings() }
                                                    }
                                                    .padding(.leading, 52)
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.bottom, 12)
                                        }
                                    }
                                    Divider().padding(.leading, 40)
                                }
                                
                                VStack(spacing: 0) {
                                    CustomSettingsRow(icon: "battery.100", iconColor: .green, title: "Fully charged", subtitle: "Show when reaching full charge") {
                                        HStack(spacing: 8) {
                                            if settings.notifyOn100Percent {
                                                SoundPickerControl(selectedSound: $settings.soundOn100Percent)
                                                    .onChange(of: settings.soundOn100Percent) { _, _ in saveSettings() }
                                            }
                                            Toggle("", isOn: $settings.notifyOn100Percent)
                                                .labelsHidden()
                                                .onChange(of: settings.notifyOn100Percent) { _, _ in saveSettings() }
                                            
                                            if deviceName.lowercased().contains("airpods") {
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .rotationEffect(.degrees(isFullyChargedExpanded ? 180 : 0))
                                                    .foregroundColor(.secondary)
                                                    .frame(width: 20, height: 20)
                                            }
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if deviceName.lowercased().contains("airpods") {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                isFullyChargedExpanded.toggle()
                                            }
                                        }
                                    }
                                    
                                    if isFullyChargedExpanded {
                                        VStack(spacing: 8) {

                                            if deviceName.lowercased().contains("airpods") {
                                                HStack {
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text("Target Devices")
                                                            .font(.system(size: 13, weight: .medium))
                                                            .foregroundColor(.primary)
                                                        Text("Which components trigger this alert?")
                                                            .font(.system(size: 11))
                                                            .foregroundColor(.secondary)
                                                    }
                                                    Spacer()
                                                    HStack(spacing: 12) {
                                                        Toggle("Left", isOn: $settings.apply100PercentToLeft)
                                                        Toggle("Case", isOn: $settings.apply100PercentToCase)
                                                        Toggle("Right", isOn: $settings.apply100PercentToRight)
                                                    }
                                                    .toggleStyle(.checkbox)
                                                    .font(.system(size: 11))
                                                    .onChange(of: settings.apply100PercentToLeft) { _, _ in saveSettings() }
                                                    .onChange(of: settings.apply100PercentToRight) { _, _ in saveSettings() }
                                                    .onChange(of: settings.apply100PercentToCase) { _, _ in saveSettings() }
                                                }
                                                .padding(.leading, 52)
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.bottom, 12)
                                    }
                                }
                                
                                Divider().padding(.leading, 40)
                                
                                let isMaxReached = settings.customThresholds.count >= 99
                                
                                Button(action: {
                                    withAnimation {
                                        let existing = settings.customThresholds.map { $0.percentage }
                                        let nextPct = BatteryThreshold.nextAvailablePercentage(existing: existing)
                                        settings.customThresholds.append(BatteryThreshold(percentage: nextPct, sound: "None", isEnabled: true))
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
                                    .foregroundColor(isMaxReached ? .gray : .blue)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(isMaxReached)
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
    
    private func batteryIcon(for percentage: Int) -> String {
        if percentage >= 85 { return "battery.100" }
        if percentage >= 60 { return "battery.75" }
        if percentage >= 35 { return "battery.50" }
        if percentage >= 15 { return "battery.25" }
        return "battery.0"
    }
}
