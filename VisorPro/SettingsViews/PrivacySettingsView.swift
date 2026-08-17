import SwiftUI

struct PrivacySettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("micOverlayPosition") private var micOverlayPosition: String = "top"
    @AppStorage("cameraOverlayPosition") private var cameraOverlayPosition: String = "top"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Master Enable Section
                VStack(spacing: 0) {
                    CustomSettingsRow(icon: "power", iconColor: .blue, title: "Enable Privacy Module", subtitle: "When disabled, VisorPro completely ignores Camera and Microphone activity") {
                        Toggle("", isOn: $mediaKeyManager.enablePrivacy).labelsHidden()
                    }
                }
                .toggleStyle(.switch)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)
                
                if mediaKeyManager.enablePrivacy {
                    
                    // Previews
                    VStack(spacing: 16) {
                        Text("Preview")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        ZStack {
                            PreviewBackgroundView()
                            
                            VStack {
                                Spacer()
                                HStack(spacing: -10) {
                                    MicOverlayView(isPreview: true, previewIsActive: true)
                                        .scaleEffect(0.85)
                                    
                                    CameraOverlayView(isPreview: true, previewIsActive: true)
                                        .scaleEffect(0.85)
                                }
                                Spacer()
                            }
                        }
                        .frame(minHeight: 180)
                    }
                    
                    VStack(alignment: .leading, spacing: 24) {
                        // Category 1: Microphone Card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Microphone")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 0) {
                                CustomSettingsRow(icon: "mic.fill", iconColor: .blue, title: "Notify when Microphone is ON", subtitle: "Show an overlay when the microphone starts being used") {
                                    Toggle("", isOn: $mediaKeyManager.notifyOnMicOn).labelsHidden()
                                }
                        if mediaKeyManager.notifyOnMicOn {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnMicOn)
                        }
                                Divider().padding(.leading, 40)
                                CustomSettingsRow(icon: "mic.slash.fill", iconColor: .blue, title: "Notify when Microphone is OFF", subtitle: "Show an overlay when the microphone stops being used") {
                                    Toggle("", isOn: $mediaKeyManager.notifyOnMicOff).labelsHidden()
                                }
                        if mediaKeyManager.notifyOnMicOff {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnMicOff)
                        }
                                
                                Divider()
                                
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Overlay Position")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 10)
                                        .padding(.horizontal)
                                    
                                    HStack(spacing: 30) {
                                        Spacer()
                                        PositionPickerItem(title: "Top", isSelected: micOverlayPosition == "top") {
                                            micOverlayPosition = "top"
                                        }
                                        PositionPickerItem(title: "Bottom", isSelected: micOverlayPosition == "bottom") {
                                            micOverlayPosition = "bottom"
                                        }
                                        Spacer()
                                    }
                                    .padding(.bottom, 12)
                                }
                            }
                            .toggleStyle(.switch)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        // Category 2: Camera Card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Camera")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 0) {
                                CustomSettingsRow(icon: "video.fill", iconColor: .blue, title: "Notify when Camera is ON", subtitle: "Show an overlay when the camera starts being used") {
                                    Toggle("", isOn: $mediaKeyManager.notifyOnCameraOn).labelsHidden()
                                }
                        if mediaKeyManager.notifyOnCameraOn {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnCameraOn)
                        }
                                Divider().padding(.leading, 40)
                                CustomSettingsRow(icon: "video.slash.fill", iconColor: .blue, title: "Notify when Camera is OFF", subtitle: "Show an overlay when the camera stops being used") {
                                    Toggle("", isOn: $mediaKeyManager.notifyOnCameraOff).labelsHidden()
                                }
                        if mediaKeyManager.notifyOnCameraOff {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnCameraOff)
                        }
                                
                                Divider()
                                
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Overlay Position")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 10)
                                        .padding(.horizontal)
                                    
                                    HStack(spacing: 30) {
                                        Spacer()
                                        PositionPickerItem(title: "Top", isSelected: cameraOverlayPosition == "top") {
                                            cameraOverlayPosition = "top"
                                        }
                                        PositionPickerItem(title: "Bottom", isSelected: cameraOverlayPosition == "bottom") {
                                            cameraOverlayPosition = "bottom"
                                        }
                                        Spacer()
                                    }
                                    .padding(.bottom, 12)
                                }
                            }
                            .toggleStyle(.switch)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Privacy")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}
