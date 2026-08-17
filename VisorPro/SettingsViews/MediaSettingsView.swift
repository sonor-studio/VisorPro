import SwiftUI

struct MediaSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("mediaOverlayPosition") private var mediaOverlayPosition: String = "bottom"
    
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
                        
                        MediaOverlayView(isPreview: true)
                            .scaleEffect(0.85)
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 20)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("Notification Events")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                        
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "music.note", iconColor: .red, title: "Start Notification", subtitle: "Shows an overlay when a new track or media starts playing") {
                            Toggle("", isOn: $mediaKeyManager.notifyMediaStart).labelsHidden()
                        }
                        if mediaKeyManager.notifyMediaStart {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundMediaStart)
                        }
                        Divider().padding(.leading, 40)
                        CustomSettingsRow(icon: "pause.fill", iconColor: .red, title: "Pause Notification", subtitle: "Shows an overlay when you pause the current media") {
                            Toggle("", isOn: $mediaKeyManager.notifyMediaPause).labelsHidden()
                        }
                        if mediaKeyManager.notifyMediaPause {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundMediaPause)
                        }
                        Divider().padding(.leading, 40)
                        CustomSettingsRow(icon: "play.fill", iconColor: .red, title: "Resume Notification", subtitle: "Shows an overlay when you resume paused media") {
                            Toggle("", isOn: $mediaKeyManager.notifyMediaResume).labelsHidden()
                        }
                        if mediaKeyManager.notifyMediaResume {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundMediaResume)
                        }
                        Divider().padding(.leading, 40)
                        CustomSettingsRow(icon: "stop.fill", iconColor: .red, title: "End Notification", subtitle: "Shows an overlay when the track or media ends") {
                            Toggle("", isOn: $mediaKeyManager.notifyMediaEnd).labelsHidden()
                        }
                        if mediaKeyManager.notifyMediaEnd {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundMediaEnd)
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
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("Overlay Position")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                    
                    HStack(spacing: 30) {
                        Spacer()
                        PositionPickerItem(title: "Top", isSelected: mediaOverlayPosition == "top") {
                            mediaOverlayPosition = "top"
                        }
                        PositionPickerItem(title: "Bottom", isSelected: mediaOverlayPosition == "bottom") {
                            mediaOverlayPosition = "bottom"
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12)
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
