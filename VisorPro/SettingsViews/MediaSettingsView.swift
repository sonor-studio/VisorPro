import SwiftUI

struct MediaSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("mediaOverlayPosition") private var mediaOverlayPosition: String = "top"
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("mediaAllowExpansion") private var mediaAllowExpansion: Bool = true
    @AppStorage("mediaAllowInteractivity") private var mediaAllowInteractivity: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 0) {
                    CustomSettingsRow(icon: "power", iconColor: .red, title: "Enable Multimedia Module", subtitle: "When disabled, VisorPro will not show playback notifications") {
                        Toggle("", isOn: $mediaKeyManager.enableMediaNotification).labelsHidden()
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
                        
                        MediaOverlayView(isPreview: true).applyTheme(mediaKeyManager.overlayTheme)
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
                        
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "music.note", iconColor: .red, title: "Start Notification", subtitle: "Shows an overlay when a new track or media starts playing") {
                            HStack(spacing: 8) { if mediaKeyManager.notifyMediaStart { SoundPickerControl(selectedSound: $mediaKeyManager.soundMediaStart) }
Toggle("", isOn: $mediaKeyManager.notifyMediaStart).labelsHidden() }
                       
                            }
                        Divider().padding(.leading, 40)
                        CustomSettingsRow(icon: "pause.fill", iconColor: .red, title: "Pause Notification", subtitle: "Shows an overlay when you pause the current media") {
                            HStack(spacing: 8) { if mediaKeyManager.notifyMediaPause { SoundPickerControl(selectedSound: $mediaKeyManager.soundMediaPause) }
Toggle("", isOn: $mediaKeyManager.notifyMediaPause).labelsHidden() }
                       
                            }
                        Divider().padding(.leading, 40)
                        CustomSettingsRow(icon: "play.fill", iconColor: .red, title: "Resume Notification", subtitle: "Shows an overlay when you resume paused media") {
                            HStack(spacing: 8) { if mediaKeyManager.notifyMediaResume { SoundPickerControl(selectedSound: $mediaKeyManager.soundMediaResume) }
Toggle("", isOn: $mediaKeyManager.notifyMediaResume).labelsHidden() }
                       
                            }
                        Divider().padding(.leading, 40)
                        CustomSettingsRow(icon: "stop.fill", iconColor: .red, title: "End Notification", subtitle: "Shows an overlay when the track or media ends") {
                            HStack(spacing: 8) { if mediaKeyManager.notifyMediaEnd { SoundPickerControl(selectedSound: $mediaKeyManager.soundMediaEnd) }
Toggle("", isOn: $mediaKeyManager.notifyMediaEnd).labelsHidden() }
                       
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
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Behavior")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                        .padding(.leading, 4)
                    
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
                    .toggleStyle(.switch)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Group {
                        if overlayPositionMode == "custom" {
                        Text("Overlay Position")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.top, 10)
                        
                        PositionPickerGroup(selection: $mediaOverlayPosition)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .navigationTitle("Media")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}
