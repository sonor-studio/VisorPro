import SwiftUI

struct VolumeSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    
    @AppStorage("volumeAllowExpansion") private var volumeAllowExpansion = true
    @AppStorage("volumeAllowInteractivity") private var volumeAllowInteractivity = true
    @AppStorage("volumeStep") private var volumeStep: Double = 6.25
    @AppStorage("volumeOverlayPosition") private var volumeOverlayPosition = "bottom"
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    
    @State private var showAppleEventsPermissionAlert = false
    
    var body: some View {
        ModuleSettingsLayout(
            title: "Volume",
            isEnabled: $mediaKeyManager.enableVolume,
            preview: {
                VolumeOverlayView(isPreview: true)
                    .applyTheme(mediaKeyManager.overlayTheme)
            },
            popovers: [
                ModulePopover(
                    icon: "speaker.wave.2.fill",
                    title: "Sound Settings",
                    content: AnyView(
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "speaker.wave.2.fill", iconColor: .blue, title: "Notification Sound", subtitle: "Select the sound to play when changing volume") {
                                SoundPickerControl(selectedSound: $mediaKeyManager.soundOnVolume)
                            }
                            
                            if mediaKeyManager.overlayColorMode == "custom" {
                                Divider().padding(.leading, 12)
                                CustomSettingsRow(icon: "paintpalette.fill", iconColor: .blue, title: "Notification Color", subtitle: "Select the color for this overlay") {
                                    ColorPickerControl(selectedColor: $mediaKeyManager.colorOnVolume)
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
                            CustomSettingsRow(icon: "arrow.up.left.and.arrow.down.right", iconColor: .blue, title: "Allow Expansion", subtitle: "Allow overlay to expand and show list of audio devices") {
                                Toggle("", isOn: $volumeAllowExpansion).labelsHidden()
                            }
                            
                            Divider().padding(.leading, 40)
                            
                            CustomSettingsRow(icon: "hand.tap.fill", iconColor: .blue, title: "Allow Interactivity", subtitle: "Allow dragging to change volume and tapping to mute") {
                                Toggle("", isOn: $volumeAllowInteractivity).labelsHidden()
                            }
                            
                            Divider().padding(.leading, 40)
                            
                            CustomSettingsRow(icon: "plus.forwardslash.minus", iconColor: .blue, title: "Step Size", subtitle: "Percentage to change when pressing keys") {
                                HStack {
                                    Slider(value: $volumeStep, in: 1...25, step: 1)
                                        .labelsHidden()
                                        .frame(width: 150)
                                    
                                    Text(String(format: "%.1f%%", volumeStep))
                                        .frame(width: 50, alignment: .trailing)
                                }
                            }
                        }
                    )
                ),
                ModulePopover(
                    icon: "pip",
                    title: "Position",
                    show: overlayPositionMode == "custom",
                    content: AnyView(
                        Group {
                            if overlayPositionMode == "custom" {
                                PositionPickerGroup(selection: $volumeOverlayPosition)
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
        .navigationTitle("Volume")
        .alert(isPresented: $showAppleEventsPermissionAlert) {
            Alert(
                title: Text("Apple Events Access Required"),
                message: Text("To control the system volume, VisorPro needs Apple Events (Automation) access. Please enable it in System Settings > Privacy & Security > Automation."),
                primaryButton: .default(Text("Open Settings")) {
                    PermissionHelper.openPrivacySettings(for: "AppleEvents")
                },
                secondaryButton: .cancel()
            )
        }
    }
}
