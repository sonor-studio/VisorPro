import SwiftUI

struct BrightnessSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("brightnessOverlayPosition") private var brightnessOverlayPosition: String = "top"
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("brightnessFillCenter") private var brightnessFillCenter: Bool = false
    @AppStorage("brightnessStep") private var brightnessStep: Double = 6.0
    @AppStorage("brightnessAllowInteractivity") private var brightnessAllowInteractivity: Bool = true
    @AppStorage("brightnessAllowExpansion") private var brightnessAllowExpansion: Bool = true
    @State private var showAppleEventsPermissionAlert: Bool = false
    
    var body: some View {
        ModuleSettingsLayout(
            title: "Brightness",
            isEnabled: $mediaKeyManager.enableBrightness,
            preview: {
                BrightnessOverlayView(isPreview: true)
                    .applyTheme(mediaKeyManager.overlayTheme)
            },
            popovers: [
                ModulePopover(
                    icon: "speaker.wave.2.fill",
                    title: "Sound Settings",
                    content: AnyView(
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "speaker.wave.2.fill", iconColor: .yellow, title: "Notification Sound", subtitle: "Select the sound to play when changing brightness") {
                                SoundPickerControl(selectedSound: $mediaKeyManager.soundOnBrightness)
                            }
                            
                            if mediaKeyManager.overlayColorMode == "custom" {
                                Divider().padding(.leading, 12)
                                CustomSettingsRow(icon: "paintpalette.fill", iconColor: .yellow, title: "Notification Color", subtitle: "Select the color for this overlay") {
                                    ColorPickerControl(selectedColor: $mediaKeyManager.colorOnBrightness)
                                }
                            }
                        }
                    )
                ),
                ModulePopover(
                    icon: "slider.horizontal.3",
                    title: "Behavior",
                    content: AnyView(
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "plus.forwardslash.minus", iconColor: .yellow, title: "Step Size", subtitle: "Percentage to change when pressing keys") {
                                HStack {
                                    Slider(value: $brightnessStep, in: 1...25, step: 1)
                                        .labelsHidden()
                                        .frame(width: 150)
                                    
                                    Text(String(format: "%.1f%%", brightnessStep))
                                        .frame(width: 50, alignment: .trailing)
                                }
                            }
                            
                            Divider().padding(.leading, 40)
                            
                            CustomSettingsRow(icon: "arrow.up.left.and.arrow.down.right", iconColor: .yellow, title: "Allow Expansion", subtitle: "Allow overlay to expand and show True Tone and Night Shift") {
                                Toggle("", isOn: $brightnessAllowExpansion).labelsHidden()
                            }
                            
                            Divider().padding(.leading, 40)
                            
                            CustomSettingsRow(icon: "hand.tap.fill", iconColor: .yellow, title: "Allow Interactivity", subtitle: "Allow dragging horizontally to change brightness") {
                                Toggle("", isOn: $brightnessAllowInteractivity).labelsHidden()
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
                                PositionPickerGroup(selection: $brightnessOverlayPosition)
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
        .navigationTitle("Brightness")
        .alert(isPresented: $showAppleEventsPermissionAlert) {
            Alert(
                title: Text("Apple Events Access Required"),
                message: Text("To control the screen brightness, VisorPro needs Apple Events (Automation) access. Please enable it in System Settings > Privacy & Security > Automation."),
                primaryButton: .default(Text("Open Settings")) {
                    PermissionHelper.openPrivacySettings(for: "AppleEvents")
                },
                secondaryButton: .cancel()
            )
        }
    }
}
