import SwiftUI

struct AccessorySettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    let deviceName: String
    
    // We use a local state to bind to, and sync it with MediaKeyManager
    @State private var settings: AccessoryDeviceSettings = AccessoryDeviceSettings()
    @State private var expandedThresholds: Set<UUID> = []
    @State private var isFullyChargedExpanded: Bool = false
    @State private var showForgetConfirmation: Bool = false
    
    private var isHeadphones: Bool {
        let lower = deviceName.lowercased()
        return lower.contains("airpod") || lower.contains("headphone") || lower.contains("ear") || lower.contains("buds") || lower.contains("headset")
    }
    
    var body: some View {
        ModuleSettingsLayout(
            title: deviceName,
            isEnabled: Binding(
                get: { settings.enableOverlay },
                set: { newValue in
                    settings.enableOverlay = newValue
                    saveSettings()
                }
            ),
            isPremium: true,
            preview: {
                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 56)
                        
                        Spacer()
                        
                        componentsOverview()
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    HStack(alignment: .center, spacing: 20) {
                        BluetoothOverlayView(isPreview: true, previewIsAccessory: true, previewIsConnected: true, previewDeviceName: deviceName, previewAccessorySettings: settings)
                            .applyTheme(mediaKeyManager.overlayTheme)
                            .frame(height: 56, alignment: .center)
                            
                        BluetoothOverlayView(isPreview: true, previewIsAccessory: true, previewIsConnected: false, previewDeviceName: deviceName, previewAccessorySettings: settings)
                            .applyTheme(mediaKeyManager.overlayTheme)
                            .frame(height: 56, alignment: .center)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(height: 56, alignment: .center)
                    .zIndex(10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            },
            popovers: [
                ModulePopover(
                    icon: "link",
                    title: "Overlay Triggers",
                    content: AnyView(
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "link", iconColor: .blue, title: "On Connect", subtitle: "Show overlay and play sound when connected") {
                                HStack(spacing: 8) {
                                    if settings.notifyOnConnect {
                                        if mediaKeyManager.overlayColorMode == "custom" {
                                            ColorPickerControl(selectedColor: Binding(
                                                get: { settings.colorOnConnect },
                                                set: { newValue in
                                                    settings.colorOnConnect = newValue
                                                    saveSettings()
                                                }
                                            ))
                                        }
                                        if !isHeadphones {
                                            SoundPickerControl(selectedSound: Binding(
                                                get: { settings.soundOnConnect },
                                                set: { newValue in
                                                    settings.soundOnConnect = newValue
                                                    saveSettings()
                                                }
                                            ))
                                        }
                                    }
                                    Toggle("", isOn: Binding(
                                        get: { settings.notifyOnConnect },
                                        set: { newValue in
                                            settings.notifyOnConnect = newValue
                                            saveSettings()
                                        }
                                    ))
                                    .labelsHidden()
                                }
                            }
                            
                            Divider().padding(.leading, 40)
                            
                            CustomSettingsRow(icon: "link.badge.plus", iconColor: .orange, title: "On Disconnect", subtitle: "Show overlay and play sound when disconnected") {
                                HStack(spacing: 8) {
                                    if settings.notifyOnDisconnect {
                                        if !isHeadphones {
                                            SoundPickerControl(selectedSound: Binding(
                                                get: { settings.soundOnDisconnect },
                                                set: { newValue in
                                                    settings.soundOnDisconnect = newValue
                                                    saveSettings()
                                                }
                                            ))
                                        }
                                    }
                                    Toggle("", isOn: Binding(
                                        get: { settings.notifyOnDisconnect },
                                        set: { newValue in
                                            settings.notifyOnDisconnect = newValue
                                            saveSettings()
                                        }
                                    ))
                                    .labelsHidden()
                                }
                            }
                            
                            if deviceName.lowercased().contains("airpod") || deviceName.lowercased().contains("beats") {
                                Divider().padding(.leading, 40)
                                
                                CustomSettingsRow(icon: "arrow.right.arrow.left", iconColor: .purple, title: "On Audio Transfer", subtitle: "Show overlay when audio transfers to another device") {
                                    HStack(spacing: 8) {
                                        if settings.notifyOnSmartRouting {
                                            if mediaKeyManager.overlayColorMode == "custom" {
                                                ColorPickerControl(selectedColor: Binding(
                                                    get: { settings.colorOnSmartRouting },
                                                    set: { newValue in
                                                        settings.colorOnSmartRouting = newValue
                                                        saveSettings()
                                                    }
                                                ))
                                            }
                                        }
                                        Toggle("", isOn: Binding(
                                            get: { settings.notifyOnSmartRouting },
                                            set: { newValue in
                                                settings.notifyOnSmartRouting = newValue
                                                saveSettings()
                                            }
                                        ))
                                        .labelsHidden()
                                    }
                                }
                                
                                Divider().padding(.leading, 40)
                                
                                CustomSettingsRow(icon: "airpodspro.chargingcase.wireless.fill", iconColor: .blue, title: "On Case Opened", subtitle: "Show battery overlay when case lid is opened") {
                                    HStack(spacing: 8) {
                                        if mediaKeyManager.overlayColorMode == "custom" {
                                            ColorPickerControl(selectedColor: Binding(
                                                get: { settings.colorOnCaseOpen },
                                                set: { newValue in
                                                    settings.colorOnCaseOpen = newValue
                                                    saveSettings()
                                                }
                                            ))
                                        }
                                        if settings.notifyOnCaseOpen {
                                            SoundPickerControl(selectedSound: Binding(
                                                get: { settings.soundOnCaseOpen },
                                                set: { newValue in
                                                    settings.soundOnCaseOpen = newValue
                                                    saveSettings()
                                                }
                                            ))
                                        }
                                        Toggle("", isOn: Binding(
                                            get: { settings.notifyOnCaseOpen },
                                            set: { newValue in
                                                settings.notifyOnCaseOpen = newValue
                                                saveSettings()
                                            }
                                        ))
                                        .labelsHidden()
                                    }
                                }
                            }
                        }
                    )
                ),
                ModulePopover(
                    icon: "list.bullet",
                    title: "Overlay Content",
                    content: AnyView(
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "battery.100", iconColor: .green, title: "Show Battery", subtitle: "Display battery percentage in the expanded overlay") {
                                Toggle("", isOn: Binding(
                                    get: { settings.showBattery },
                                    set: { newValue in
                                        settings.showBattery = newValue
                                        saveSettings()
                                    }
                                ))
                                .labelsHidden()
                                .disabled(settings.showBattery && !settings.showDetails)
                            }
                            
                            Divider().padding(.leading, 40)
                            
                            CustomSettingsRow(icon: "info.circle", iconColor: .blue, title: "Show Details", subtitle: "Display device details like MAC address and firmware in the expanded overlay") {
                                Toggle("", isOn: Binding(
                                    get: { settings.showDetails },
                                    set: { newValue in
                                        settings.showDetails = newValue
                                        saveSettings()
                                    }
                                ))
                                .labelsHidden()
                                .disabled(settings.showDetails && !settings.showBattery)
                            }
                        }
                    )
                ),
                ModulePopover(
                    icon: "bell",
                    title: "Battery Alerts",
                    content: AnyView(
                        VStack(spacing: 0) {
                            ForEach($settings.customThresholds) { $threshold in
                                let isExpanded = expandedThresholds.contains(threshold.id)
                                VStack(spacing: 0) {
                                    CustomSettingsRow(icon: "bell", iconColor: .green, title: "Alert at \(threshold.percentage)%", subtitle: "Custom battery threshold") {
                                        HStack(spacing: 8) {
                                            Stepper(onIncrement: {
                                                let existing = settings.customThresholds.filter { $0.id != threshold.id }.map { $0.percentage }
                                                $threshold.wrappedValue.percentage = BatteryThreshold.nextIncrement(current: threshold.percentage, existing: existing)
                                                saveSettings()
                                            }, onDecrement: {
                                                let existing = settings.customThresholds.filter { $0.id != threshold.id }.map { $0.percentage }
                                                $threshold.wrappedValue.percentage = BatteryThreshold.nextDecrement(current: threshold.percentage, existing: existing)
                                                saveSettings()
                                            }) {
                                                Text("\(threshold.percentage)%")
                                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                                    .foregroundColor(.primary)
                                            }
                                            .frame(width: 80)
                                            .disabled(settings.customThresholds.count >= 99)
                                            
                                            if threshold.isEnabled {
                                                SoundPickerControl(selectedSound: Binding(
                                                    get: { threshold.sound },
                                                    set: { newValue in
                                                        $threshold.wrappedValue.sound = newValue
                                                        saveSettings()
                                                    }
                                                ))
                                            }
                                            
                                            Toggle("", isOn: Binding(
                                                get: { threshold.isEnabled },
                                                set: { newValue in
                                                    $threshold.wrappedValue.isEnabled = newValue
                                                    saveSettings()
                                                }
                                            ))
                                            .labelsHidden()
                                            
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
                                                Picker("", selection: Binding(
                                                    get: { threshold.triggerDirection },
                                                    set: { newValue in
                                                        $threshold.wrappedValue.triggerDirection = newValue
                                                        saveSettings()
                                                    }
                                                )) {
                                                    Text("Any").tag("both")
                                                    Text("Charge").tag("up")
                                                    Text("Drain").tag("down")
                                                }
                                                .pickerStyle(.segmented)
                                                .fixedSize()
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
                                                        Toggle("Left", isOn: Binding(
                                                            get: { threshold.applyToLeft },
                                                            set: { newValue in
                                                                $threshold.wrappedValue.applyToLeft = newValue
                                                                saveSettings()
                                                            }
                                                        ))
                                                        Toggle("Case", isOn: Binding(
                                                            get: { threshold.applyToCase },
                                                            set: { newValue in
                                                                $threshold.wrappedValue.applyToCase = newValue
                                                                saveSettings()
                                                            }
                                                        ))
                                                        Toggle("Right", isOn: Binding(
                                                            get: { threshold.applyToRight },
                                                            set: { newValue in
                                                                $threshold.wrappedValue.applyToRight = newValue
                                                                saveSettings()
                                                            }
                                                        ))
                                                    }
                                                    .toggleStyle(.checkbox)
                                                    .font(.system(size: 11))
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
                                            SoundPickerControl(selectedSound: Binding(
                                                get: { settings.soundOn100Percent },
                                                set: { newValue in
                                                    settings.soundOn100Percent = newValue
                                                    saveSettings()
                                                }
                                            ))
                                        }
                                        Toggle("", isOn: Binding(
                                            get: { settings.notifyOn100Percent },
                                            set: { newValue in
                                                settings.notifyOn100Percent = newValue
                                                saveSettings()
                                            }
                                        ))
                                        .labelsHidden()
                                        
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
                                                    Toggle("Left", isOn: Binding(
                                                        get: { settings.apply100PercentToLeft },
                                                        set: { newValue in
                                                            settings.apply100PercentToLeft = newValue
                                                            saveSettings()
                                                        }
                                                    ))
                                                    Toggle("Case", isOn: Binding(
                                                        get: { settings.apply100PercentToCase },
                                                        set: { newValue in
                                                            settings.apply100PercentToCase = newValue
                                                            saveSettings()
                                                        }
                                                    ))
                                                    Toggle("Right", isOn: Binding(
                                                        get: { settings.apply100PercentToRight },
                                                        set: { newValue in
                                                            settings.apply100PercentToRight = newValue
                                                            saveSettings()
                                                        }
                                                    ))
                                                }
                                                .toggleStyle(.checkbox)
                                                .font(.system(size: 11))
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
                        }
                    )
                ),
                ModulePopover(
                    icon: "earbuds",
                    title: "Listening Modes",
                    content: AnyView(
                        Group {
                            let lowerName = deviceName.lowercased()
                            if lowerName.contains("airpod") || lowerName.contains("beats") {
                                VStack(spacing: 0) {
                                    CustomSettingsRow(icon: "earbuds.case.fill", iconColor: .indigo, title: "Noise Cancellation", subtitle: "Show overlay for ANC mode") {
                                        HStack {
                                            if mediaKeyManager.overlayColorMode == "custom" {
                                                ColorPickerControl(selectedColor: $settings.colorOnAirPodsANC)
                                            }
                                            Toggle("", isOn: $mediaKeyManager.notifyOnAirPodsANC).labelsHidden()
                                        }
                                    }
                                    Divider().padding(.leading, 40)
                                    CustomSettingsRow(icon: "earbuds", iconColor: .indigo, title: "Transparency", subtitle: "Show overlay for transparency mode") {
                                        HStack {
                                            if mediaKeyManager.overlayColorMode == "custom" {
                                                ColorPickerControl(selectedColor: $settings.colorOnAirPodsTransparency)
                                            }
                                            Toggle("", isOn: $mediaKeyManager.notifyOnAirPodsTransparency).labelsHidden()
                                        }
                                    }
                                    Divider().padding(.leading, 40)
                                    CustomSettingsRow(icon: "earbuds.case", iconColor: .indigo, title: "Adaptive Audio", subtitle: "Show overlay for adaptive mode") {
                                        HStack {
                                            if mediaKeyManager.overlayColorMode == "custom" {
                                                ColorPickerControl(selectedColor: $settings.colorOnAirPodsAdaptive)
                                            }
                                            Toggle("", isOn: $mediaKeyManager.notifyOnAirPodsAdaptive).labelsHidden()
                                        }
                                    }
                                    Divider().padding(.leading, 40)
                                    CustomSettingsRow(icon: "airpods", iconColor: .indigo, title: "Off", subtitle: "Show overlay for off mode") {
                                        HStack {
                                            if mediaKeyManager.overlayColorMode == "custom" {
                                                ColorPickerControl(selectedColor: $settings.colorOnAirPodsOff)
                                            }
                                            Toggle("", isOn: $mediaKeyManager.notifyOnAirPodsOff).labelsHidden()
                                        }
                                    }
                                }
                            } else {
                                CustomSettingsRow(icon: "info.circle", iconColor: .gray, title: "Not Supported", subtitle: "Listening modes are only supported for AirPods and Beats devices.") {
                                    EmptyView()
                                }
                            }
                        }
                    )
                )
            ],
            inlineControls: [
                AnyView(
                    InlineControlView(
                        icon: "arrow.up.left.and.arrow.down.right",
                        title: "Allow Expansion",
                        control: Toggle("", isOn: Binding(
                            get: { settings.allowExpansion },
                            set: { newValue in
                                settings.allowExpansion = newValue
                                saveSettings()
                            }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    )
                )
            ],
            headerTrailingControls: AnyView(
                Button(action: {
                    showForgetConfirmation = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Forget")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .buttonStyle(InteractiveGlassButtonStyle(isActive: true, tintColor: .red))
            ),
            previewTopOffset: 60
        )
        .alert("Forget \"\(deviceName)\"?", isPresented: $showForgetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Forget", role: .destructive) {
                mediaKeyManager.forgetAccessory(name: deviceName)
            }
        } message: {
            Text("Are you sure you want to forget this device? All custom settings and battery history for this device will be removed.")
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
    
    
    @ViewBuilder
    private func componentsOverview() -> some View {
        let hasComponents = mediaKeyManager.accessoryBatteryHistory.contains { $0.hasPrefix(deviceName) && $0 != deviceName }
        
        VStack(spacing: 14) {
            Text(deviceName)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.primary)
            
            if hasComponents {
                HStack(spacing: 20) {
                    batteryComponent(title: "Left", icon: "airpodpro.left", key: "\(deviceName) (Left)")
                    
                    Divider().frame(height: 48).opacity(0.25)
                    
                    batteryComponent(title: "Case", icon: "airpodspro.chargingcase.wireless.fill", key: "\(deviceName) (Case)")
                    
                    Divider().frame(height: 48).opacity(0.25)
                    
                    batteryComponent(title: "Right", icon: "airpodpro.right", key: "\(deviceName) (Right)")
                }
                .padding(.horizontal, 6)
            } else {
                singleAccessoryRow()
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .visorGlassEffect(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
    
    @ViewBuilder
    private func batteryComponent(title: String, icon: String, key: String) -> some View {
        let pct = mediaKeyManager.accessoryBatteryLevels[key]
        let isCharging = (OverlayStateRelay.shared.airpodsDeviceName == deviceName)
            ? (title == "Left" ? OverlayStateRelay.shared.airpodsLeftCharging : (title == "Case" ? OverlayStateRelay.shared.airpodsCaseCharging : OverlayStateRelay.shared.airpodsRightCharging))
            : (mediaKeyManager.accessoryBatteryCharging[key] == true)
        
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .light))
                .foregroundColor(.primary)
                .frame(height: 36)
            
            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    if let pct = pct {
                        if isCharging {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: batteryIcon(for: pct))
                                .font(.system(size: 10))
                                .foregroundColor(pct <= 20 ? .red : .secondary)
                        }
                        Text("\(pct)%")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                    } else {
                        Text("--%")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.4))
                    }
                }
            }
        }
        .frame(width: 80)
    }
    
    @ViewBuilder
    private func singleAccessoryRow() -> some View {
        let iconName = mediaKeyManager.peripheralIcons[deviceName] ?? MediaKeyManager.fallbackIcon(for: deviceName)
        let pct = mediaKeyManager.accessoryBatteryLevels[deviceName]
        let isCharging = mediaKeyManager.accessoryBatteryCharging[deviceName] == true
        
        HStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 22, weight: .regular))
                .foregroundColor(.primary)
                .frame(width: 42, height: 42)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Battery Status")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Text(pct != nil ? (isCharging ? "Charging" : "Connected") : "Status unknown")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let pct = pct {
                HStack(spacing: 5) {
                    if isCharging {
                        Image(systemName: "bolt.fill").font(.system(size: 12)).foregroundColor(.green)
                    } else {
                        Image(systemName: batteryIcon(for: pct)).font(.system(size: 12)).foregroundColor(pct <= 20 ? .red : .secondary)
                    }
                    Text("\(pct)%")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                }
            } else {
                Text("--%")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.4))
            }
        }
        .frame(maxWidth: 320)
    }

    private func batteryIcon(for percentage: Int) -> String {
        if percentage >= 85 { return "battery.100" }
        if percentage >= 60 { return "battery.75" }
        if percentage >= 35 { return "battery.50" }
        if percentage >= 15 { return "battery.25" }
        return "battery.0"
    }
}
