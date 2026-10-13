import SwiftUI

struct SystemSettingsView: View {
    @AppStorage("PremiumLicenseKey") private var savedLicenseKey = ""
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("showSystemModule") private var showSystemModule = true
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("ramOverlayPosition") private var ramOverlayPosition: String = "top"
    @AppStorage("fanOverlayPosition") private var fanOverlayPosition: String = "bottom"
    @AppStorage("cpuOverlayPosition") private var cpuOverlayPosition: String = "top"
    @AppStorage("trashOverlayPosition") private var trashOverlayPosition: String = "top"
    @AppStorage("systemAllowExpansion") private var systemAllowExpansion: Bool = true
    
    var body: some View {
        ModuleSettingsLayout(
            title: "System",
            isEnabled: $showSystemModule,
            isPremium: true,
            preview: {
                ZStack {
                    HStack(alignment: .center, spacing: 20) {
                        CpuTemperatureOverlayView(isPreview: true).applyTheme(mediaKeyManager.overlayTheme)
                            .id("\(mediaKeyManager.colorOnHighCpuTemp)_\(mediaKeyManager.overlayColorMode)")
                            .frame(height: 56, alignment: .center)
                        RamOverlayView(isPreview: true).applyTheme(mediaKeyManager.overlayTheme)
                            .id("\(mediaKeyManager.colorOnHighRam)_\(mediaKeyManager.overlayColorMode)")
                            .frame(height: 56, alignment: .center)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(height: 56, alignment: .center)
                }
            },
            popovers: [
                ModulePopover(
                    icon: "cpu",
                    title: "CPU Alert",
                    content: AnyView(
                        Group {
                            if savedLicenseKey.isEmpty {
                                PremiumLockedView()
                            } else {
                                VStack(spacing: 0) {
                                    CustomSettingsRow(icon: "thermometer", iconColor: .red, title: "High CPU Temp", subtitle: "Show overlay when CPU temperature is high") {
                                        HStack(spacing: 8) {
                                            if mediaKeyManager.notifyOnHighCpuTemp {
                                                SoundPickerControl(selectedSound: $mediaKeyManager.soundOnHighCpuTemp)
                                                if mediaKeyManager.overlayColorMode == "custom" { ColorPickerControl(selectedColor: $mediaKeyManager.colorOnHighCpuTemp) }
                                            }
                                            Toggle("", isOn: $mediaKeyManager.notifyOnHighCpuTemp).labelsHidden()
                                        }
                                    }
                                    if mediaKeyManager.notifyOnHighCpuTemp {
                                        Divider().padding(.leading, 48)
                                        HStack {
                                            Text("Threshold")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Slider(value: $mediaKeyManager.highCpuTempThreshold, in: 60...100, step: 5)
                                                .frame(width: 150)
                                            Text("\(Int(mediaKeyManager.highCpuTempThreshold))°C")
                                                .font(.system(size: 13))
                                                .foregroundColor(.secondary)
                                                .frame(width: 45, alignment: .trailing)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                    }
                                }
                            }
                        }
                    )
                ),
                ModulePopover(
                    icon: "pip",
                    title: "CPU Position",
                    show: overlayPositionMode == "custom",
                    content: AnyView(
                        Group {
                            if savedLicenseKey.isEmpty {
                                PremiumLockedView()
                            } else {
                                if overlayPositionMode == "custom" {
                                    PositionPickerGroup(selection: $cpuOverlayPosition)
                                        .padding(.vertical, 8)
                                } else {
                                    CustomSettingsRow(icon: "exclamationmark.triangle.fill", iconColor: .orange, title: "Custom Positioning Disabled", subtitle: "Enable Custom Positioning in General Settings to modify overlay placement.") {
                                        EmptyView()
                                    }
                                }
                            }
                        }
                    )
                ),
                ModulePopover(
                    icon: "memorychip",
                    title: "RAM Alert",
                    content: AnyView(
                        Group {
                            if savedLicenseKey.isEmpty {
                                PremiumLockedView()
                            } else {
                                VStack(spacing: 0) {
                                    CustomSettingsRow(icon: "memorychip", iconColor: .red, title: "High RAM Usage", subtitle: "Show overlay when RAM usage is high") {
                                        HStack(spacing: 8) {
                                            if mediaKeyManager.notifyOnHighRam {
                                                SoundPickerControl(selectedSound: $mediaKeyManager.soundOnHighRam) 
                                                if mediaKeyManager.overlayColorMode == "custom" { ColorPickerControl(selectedColor: $mediaKeyManager.colorOnHighRam) }
                                            }
                                            Toggle("", isOn: $mediaKeyManager.notifyOnHighRam).labelsHidden()
                                        }
                                    }
                                    if mediaKeyManager.notifyOnHighRam {
                                        Divider().padding(.leading, 48)
                                        HStack {
                                            Text("Threshold")
                                            Spacer()
                                            Text("\(Int(mediaKeyManager.highRamThreshold))%")
                                                .foregroundColor(.secondary)
                                                .frame(width: 40, alignment: .trailing)
                                            Slider(value: $mediaKeyManager.highRamThreshold, in: 70.0...95.0, step: 5.0)
                                                .frame(width: 150)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                    }
                                }
                            }
                        }
                    )
                ),
                ModulePopover(
                    icon: "pip",
                    title: "RAM Position",
                    show: overlayPositionMode == "custom",
                    content: AnyView(
                        Group {
                            if savedLicenseKey.isEmpty {
                                PremiumLockedView()
                            } else {
                                if overlayPositionMode == "custom" {
                                    PositionPickerGroup(selection: $ramOverlayPosition)
                                        .padding(.vertical, 8)
                                } else {
                                    CustomSettingsRow(icon: "exclamationmark.triangle.fill", iconColor: .orange, title: "Custom Positioning Disabled", subtitle: "Enable Custom Positioning in General Settings to modify overlay placement.") {
                                        EmptyView()
                                    }
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
                        control: Toggle("", isOn: $systemAllowExpansion)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    )
                )
            ]
        )
        .navigationTitle("System")
    }
}
