import SwiftUI

struct PrivacySettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("micOverlayPosition") private var micOverlayPosition: String = "top"
    @AppStorage("cameraOverlayPosition") private var cameraOverlayPosition: String = "top"
    @AppStorage("locationOverlayPosition") private var locationOverlayPosition: String = "top"
    
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
                                    
                                    PositionPickerGroup(selection: $micOverlayPosition)
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
                                    
                                    PositionPickerGroup(selection: $cameraOverlayPosition)
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
                        
                        // Category 3: Location Card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Location")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 0) {
                                CustomSettingsRow(icon: "location.fill", iconColor: .blue, title: "Notify on Location Request", subtitle: "Show an overlay when location services are requested") {
                                    Toggle("", isOn: $mediaKeyManager.notifyOnLocationOn).labelsHidden()
                                }
                                if mediaKeyManager.notifyOnLocationOn {
                                    SoundPickerRow(selectedSound: $mediaKeyManager.soundOnLocationOn)
                                }
                                
                                Divider()
                                
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Overlay Position")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 10)
                                        .padding(.horizontal)
                                    
                                    PositionPickerGroup(selection: $locationOverlayPosition)
                                        .padding(.bottom, 12)
                                }
                                
                                Divider()
                                
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("App Filters")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 10)
                                        .padding(.horizontal)
                                        .padding(.bottom, 5)
                                    
                                    CustomSettingsRow(icon: "gearshape", iconColor: .gray, title: "System Services", subtitle: "Diagnostic tools, background daemons") {
                                        Toggle("", isOn: $mediaKeyManager.locationShowSystemServices).labelsHidden()
                                    }
                                    CustomSettingsRow(icon: "cloud.sun.fill", iconColor: .blue, title: "Weather", subtitle: "Apple Weather app & widgets") {
                                        Toggle("", isOn: $mediaKeyManager.locationShowWeather).labelsHidden()
                                    }
                                    CustomSettingsRow(icon: "map.fill", iconColor: .green, title: "Maps", subtitle: "Apple Maps") {
                                        Toggle("", isOn: $mediaKeyManager.locationShowMaps).labelsHidden()
                                    }
                                    CustomSettingsRow(icon: "safari.fill", iconColor: .blue, title: "Safari", subtitle: "Websites requesting location") {
                                        Toggle("", isOn: $mediaKeyManager.locationShowSafari).labelsHidden()
                                    }
                                    CustomSettingsRow(icon: "app.dashed", iconColor: .purple, title: "Other Apps", subtitle: "Any other application") {
                                        Toggle("", isOn: $mediaKeyManager.locationShowOtherApps).labelsHidden()
                                    }
                                }
                                .padding(.bottom, 8)
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
