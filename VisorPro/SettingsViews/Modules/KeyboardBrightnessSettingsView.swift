import SwiftUI

struct KeyboardBrightnessSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("keyboardBrightnessOverlayPosition") private var keyboardBrightnessOverlayPosition: String = "top"
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("keyboardBrightnessFillCenter") private var keyboardBrightnessFillCenter: Bool = false
    @AppStorage("keyboardBrightnessStep") private var keyboardBrightnessStep: Double = 15.0
    
    var body: some View {
        ModuleSettingsLayout(
            title: "Keyboard Brightness",
            isEnabled: $mediaKeyManager.enableKeyboardBrightness,
            preview: {
                KeyboardBrightnessOverlayView(isPreview: true)
                    .applyTheme(mediaKeyManager.overlayTheme)
            },
            popovers: [
                ModulePopover(
                    icon: "speaker.wave.2.fill",
                    title: "Sound Settings",
                    content: AnyView(
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "speaker.wave.2.fill", iconColor: .orange, title: "Notification Sound", subtitle: "Select the sound to play when changing keyboard brightness") {
                                SoundPickerControl(selectedSound: $mediaKeyManager.soundOnKeyboardBrightness)
                            }
                            
                            if mediaKeyManager.overlayColorMode == "custom" {
                                Divider().padding(.leading, 12)
                                CustomSettingsRow(icon: "paintpalette.fill", iconColor: .orange, title: "Notification Color", subtitle: "Select the color for this overlay") {
                                    ColorPickerControl(selectedColor: $mediaKeyManager.colorOnKeyboardBrightness)
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
                            CustomSettingsRow(icon: "keyboard", iconColor: .orange, title: "Modifier Key", subtitle: "Key to hold while adjusting brightness") {
                                Picker("", selection: $mediaKeyManager.keyboardBrightnessModifier) {
                                    Text("Command ⌘").tag("command")
                                    Text("Option ⌥").tag("option")
                                    Text("Control ⌃").tag("control")
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(width: 140)
                            }
                            
                            Divider().padding(.leading, 40)
                            
                            CustomSettingsRow(icon: "plus.forwardslash.minus", iconColor: .orange, title: "Step Size", subtitle: "Percentage to change when pressing keys") {
                                HStack {
                                    Slider(value: $keyboardBrightnessStep, in: 1...25, step: 1)
                                        .labelsHidden()
                                        .frame(width: 150)
                                    
                                    Text(String(format: "%.1f%%", keyboardBrightnessStep))
                                        .frame(width: 50, alignment: .trailing)
                                }
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
                                PositionPickerGroup(selection: $keyboardBrightnessOverlayPosition)
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
        .navigationTitle("Keyboard Brightness")
    }
}
