import SwiftUI

struct MediaSettingsView: View {
    @AppStorage("PremiumLicenseKey") private var savedLicenseKey = ""
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("mediaOverlayPosition") private var mediaOverlayPosition: String = "top"
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("mediaAllowExpansion") private var mediaAllowExpansion: Bool = true
    @AppStorage("mediaAllowInteractivity") private var mediaAllowInteractivity: Bool = true
    @State private var showAppleEventsPermissionAlert: Bool = false
    
    var body: some View {
        ModuleSettingsLayout(
            title: "Multimedia",
            isEnabled: $mediaKeyManager.enableMediaNotification,
            isPremium: true,
            preview: {
                MediaOverlayView(isPreview: true).applyTheme(mediaKeyManager.overlayTheme)
            },
            popovers: [
                ModulePopover(
                    icon: "bell.fill",
                    title: "Overlay Triggers",
                    content: AnyView(
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "music.note", iconColor: .red, title: "Start Notification", subtitle: "Shows an overlay when a new track or media starts playing") {
                                HStack(spacing: 8) { 
                                    if mediaKeyManager.notifyMediaStart { 
                                        SoundPickerControl(selectedSound: $mediaKeyManager.soundMediaStart) 
                                        if mediaKeyManager.overlayColorMode == "custom" { 
                                            ColorPickerControl(selectedColor: $mediaKeyManager.colorMediaStart) 
                                        } 
                                    }
                                    Toggle("", isOn: $mediaKeyManager.notifyMediaStart).labelsHidden() 
                                }
                            }
                            Divider().padding(.leading, 40)
                            CustomSettingsRow(icon: "pause.fill", iconColor: .red, title: "Pause Notification", subtitle: "Shows an overlay when you pause the current media") {
                                HStack(spacing: 8) { 
                                    if mediaKeyManager.notifyMediaPause { 
                                        SoundPickerControl(selectedSound: $mediaKeyManager.soundMediaPause) 
                                        if mediaKeyManager.overlayColorMode == "custom" { 
                                            ColorPickerControl(selectedColor: $mediaKeyManager.colorMediaPause) 
                                        } 
                                    }
                                    Toggle("", isOn: $mediaKeyManager.notifyMediaPause).labelsHidden() 
                                }
                            }
                            Divider().padding(.leading, 40)
                            CustomSettingsRow(icon: "play.fill", iconColor: .red, title: "Resume Notification", subtitle: "Shows an overlay when you resume paused media") {
                                HStack(spacing: 8) { 
                                    if mediaKeyManager.notifyMediaResume { 
                                        SoundPickerControl(selectedSound: $mediaKeyManager.soundMediaResume) 
                                        if mediaKeyManager.overlayColorMode == "custom" { 
                                            ColorPickerControl(selectedColor: $mediaKeyManager.colorMediaResume) 
                                        } 
                                    }
                                    Toggle("", isOn: $mediaKeyManager.notifyMediaResume).labelsHidden() 
                                }
                            }
                            Divider().padding(.leading, 40)
                            CustomSettingsRow(icon: "stop.fill", iconColor: .red, title: "End Notification", subtitle: "Shows an overlay when the track or media ends") {
                                HStack(spacing: 8) {
                                    if mediaKeyManager.notifyMediaEnd { 
                                        SoundPickerControl(selectedSound: $mediaKeyManager.soundMediaEnd) 
                                    }
                                    Toggle("", isOn: $mediaKeyManager.notifyMediaEnd).labelsHidden()
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
                            CustomSettingsRow(icon: "arrow.up.left.and.arrow.down.right", iconColor: .red, title: "Allow Expansion", subtitle: "Allow overlay to expand and show playback controls") {
                                Toggle("", isOn: $mediaAllowExpansion).labelsHidden()
                            }
                        
                            Divider().padding(.leading, 40)
                        
                            CustomSettingsRow(icon: "hand.tap.fill", iconColor: .red, title: "Allow Interactivity", subtitle: "Allow dragging to seek and tapping to play/pause") {
                                Toggle("", isOn: $mediaAllowInteractivity).labelsHidden()
                            }
                            Divider().padding(.leading, 40)
                        
                            CustomSettingsRow(icon: "goforward.10", iconColor: .red, title: "Skip Duration", subtitle: "Seconds to skip forward/backward") {
                                HStack {
                                    Slider(value: $mediaKeyManager.mediaSkipDuration, in: 5...20, step: 5)
                                    .labelsHidden()
                                    .frame(width: 150)
                                
                                    Text("\(Int(mediaKeyManager.mediaSkipDuration))s")
                                        .frame(width: 30, alignment: .trailing)
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
                                PositionPickerGroup(selection: $mediaOverlayPosition)
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
        .navigationTitle("Media")
        .alert(isPresented: $showAppleEventsPermissionAlert) {
            Alert(
                title: Text("Apple Events Access Required"),
                message: Text("To show media playback notifications, VisorPro needs Apple Events (Automation) access. Please enable it in System Settings > Privacy & Security > Automation."),
                primaryButton: .default(Text("Open Settings")) {
                    PermissionHelper.openPrivacySettings(for: "AppleEvents")
                },
                secondaryButton: .cancel()
            )
        }
    }
}
