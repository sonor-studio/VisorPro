import SwiftUI

struct BrightnessSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("brightnessOverlayPosition") private var brightnessOverlayPosition: String = "top"
    @AppStorage("brightnessFillCenter") private var brightnessFillCenter: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Brightness Module")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Text("Module Configuration")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                        
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "power", iconColor: .yellow, title: "Enable Brightness Module", subtitle: "When disabled, VisorPro completely ignores brightness keys and macOS handles them natively") {
                            Toggle("", isOn: $mediaKeyManager.enableBrightness).labelsHidden()
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
                

                
                VStack(alignment: .center) {
                    Text("Preview")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ZStack {
                        PreviewBackgroundView()
                        
                        BrightnessOverlayView(isPreview: true)
                            .scaleEffect(0.85)
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 20)
                
                Divider()
                
                if mediaKeyManager.enableBrightness {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sound Settings")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                            
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "speaker.wave.2.fill", iconColor: .yellow, title: "Notification Sound", subtitle: "Select the sound to play when changing brightness") {
                                SoundPickerControl(selectedSound: $mediaKeyManager.soundOnBrightness)
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
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Visual Style")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                        .padding(.leading, 4)
                    
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "paintpalette.fill", iconColor: .yellow, title: "Fill Center", subtitle: "Fills the inside of the overlay with white color instead of just the border") {
                            Toggle("", isOn: $brightnessFillCenter).labelsHidden()
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
                    
                    PositionPickerGroup(selection: $brightnessOverlayPosition)
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .navigationTitle("Brightness")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}
