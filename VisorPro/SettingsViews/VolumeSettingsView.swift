import SwiftUI

struct VolumeSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("volumeOverlayPosition") private var volumeOverlayPosition: String = "top"
    @AppStorage("volumeFillCenter") private var volumeFillCenter: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 0) {
                    CustomSettingsRow(icon: "power", iconColor: .blue, title: "Enable Volume Module", subtitle: "When disabled, VisorPro completely ignores volume keys and macOS handles them natively") {
                        Toggle("", isOn: $mediaKeyManager.enableVolume).labelsHidden()
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
                        
                        VolumeOverlayView(isPreview: true)
                            .scaleEffect(0.85)
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 20)
                
                Divider()
                
                if mediaKeyManager.enableVolume {
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "speaker.wave.2.fill", iconColor: .blue, title: "Notification Sound", subtitle: "Select the sound to play when changing volume") {
                            SoundPickerControl(selectedSound: $mediaKeyManager.soundOnVolume)
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("Visual Style")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.bottom, 4)
                        .padding(.leading, 4)
                    
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "paintpalette.fill", iconColor: .blue, title: "Fill Center", subtitle: "Fills the inside of the overlay with blue color instead of just the border") {
                            Toggle("", isOn: $volumeFillCenter).labelsHidden()
                        }
                    }
                    .toggleStyle(.switch)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
                    
                    Text("Overlay Position")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                    
                    PositionPickerGroup(selection: $volumeOverlayPosition)
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .navigationTitle("Volume")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}
