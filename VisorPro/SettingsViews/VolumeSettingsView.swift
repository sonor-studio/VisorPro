import SwiftUI

struct VolumeSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("volumeOverlayPosition") private var volumeOverlayPosition: String = "top"
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("volumeFillCenter") private var volumeFillCenter: Bool = false
    @AppStorage("volumeAllowExpansion") private var volumeAllowExpansion: Bool = true
    @AppStorage("volumeAllowInteractivity") private var volumeAllowInteractivity: Bool = true
    @AppStorage("volumeStep") private var volumeStep: Double = 6.0
    @State private var showAppleEventsPermissionAlert: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Volume Module")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Text("Module Configuration")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                        
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
                }
                .padding(.horizontal)

                if mediaKeyManager.enableVolume {
                

                
                    VStack(alignment: .center) {
                        Text("Preview")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    
                        ZStack {
                            PreviewBackgroundView()
                        
                            VolumeOverlayView(isPreview: true).applyTheme(mediaKeyManager.overlayTheme)
                                .scaleEffect(0.85)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 20)
                
                    Divider()
                
                    if mediaKeyManager.enableVolume {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Sound Settings")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 0) {
                                CustomSettingsRow(icon: "speaker.wave.2.fill", iconColor: .blue, title: "Notification Sound", subtitle: "Select the sound to play when changing volume") {
                                    SoundPickerControl(selectedSound: $mediaKeyManager.soundOnVolume)
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
                
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Behavior")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                            .padding(.leading, 4)
                    
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
                        Text("Visual Style")
                            .font(.headline)
                            .foregroundColor(.secondary)
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
                    
                        Group {
                            if overlayPositionMode == "custom" {
                            Text("Overlay Position")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.top, 10)
                        
                            PositionPickerGroup(selection: $volumeOverlayPosition)
                            }
                        }
                    }
                    .padding(.horizontal)
                
                    Spacer()
            
                } else {
                    DisabledModuleView(icon: "power", title: "Volume Module is Disabled", description: "Turn on the module to configure volume overlays.")
                }
}
        }
        .navigationTitle("Volume")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
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
