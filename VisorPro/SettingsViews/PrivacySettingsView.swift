import SwiftUI

struct PrivacySettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("micOverlayPosition") private var micOverlayPosition: String = "top"
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("cameraOverlayPosition") private var cameraOverlayPosition: String = "top"
    @AppStorage("locationOverlayPosition") private var locationOverlayPosition: String = "top"
    @State private var isMicHistoryExpanded: Bool = false
    @State private var isCameraHistoryExpanded: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Master Enable Section
                VStack(spacing: 0) {
                    CustomSettingsRow(icon: "power", iconColor: .blue, title: "Enable Privacy Module", subtitle: "When disabled, VisorPro completely ignores Camera, Microphone and Location activity") {
                        Toggle("", isOn: $mediaKeyManager.enablePrivacy).labelsHidden()
                    }
                }
                .toggleStyle(.switch)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                )
                
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
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Microphone")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                            Text("Overlay Triggers")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 4)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 0) {
                                CustomSettingsRow(icon: "mic.fill", iconColor: .blue, title: "Notify when Microphone is ON", subtitle: "Show an overlay when the microphone starts being used") {
                                    HStack(spacing: 8) { if mediaKeyManager.notifyOnMicOn { SoundPickerControl(selectedSound: $mediaKeyManager.soundOnMicOn) }
Toggle("", isOn: $mediaKeyManager.notifyOnMicOn).labelsHidden() }
                               
                            }
                                Divider().padding(.leading, 48)
                                CustomSettingsRow(icon: "mic.slash.fill", iconColor: .blue, title: "Notify when Microphone is OFF", subtitle: "Show an overlay when the microphone stops being used") {
                                    HStack(spacing: 8) { if mediaKeyManager.notifyOnMicOff { SoundPickerControl(selectedSound: $mediaKeyManager.soundOnMicOff) }
Toggle("", isOn: $mediaKeyManager.notifyOnMicOff).labelsHidden() }
                               
                            }
                            }
                            .toggleStyle(.switch)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                            )
                            
                            Group {
                                if overlayPositionMode == "custom" {
                                Text("Overlay Position")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 10)
                                    .padding(.bottom, 4)
                                    .padding(.leading, 4)
                                
                                PositionPickerGroup(selection: $micOverlayPosition)
                                }
                            }
                                .padding(.bottom, 12)
                            
                            if !mediaKeyManager.micHistory.isEmpty {
                                let displayedHistory = isMicHistoryExpanded ? mediaKeyManager.micHistory : Array(mediaKeyManager.micHistory.prefix(3))
                                
                                Text("Remembered microphones (\(mediaKeyManager.micHistory.count))")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 10)
                                    .padding(.bottom, 4)
                                    .padding(.leading, 4)
                                
                                VStack(spacing: 0) {
                                    ForEach(displayedHistory, id: \.self) { appName in
                                        let isBlocked = mediaKeyManager.micBlocklist.contains(appName)
                                        CustomSettingsRow(icon: "app", iconColor: isBlocked ? .gray : .blue, title: appName, subtitle: "Show notifications for this application", appNameForIcon: appName) {
                                            Toggle("", isOn: Binding(
                                                get: { !isBlocked },
                                                set: { isOn in
                                                    if isOn {
                                                        mediaKeyManager.micBlocklist.removeAll { $0 == appName }
                                                    } else {
                                                        if !mediaKeyManager.micBlocklist.contains(appName) {
                                                            mediaKeyManager.micBlocklist.append(appName)
                                                        }
                                                    }
                                                }
                                            )).labelsHidden()
                                        }
                                        
                                        if appName != displayedHistory.last || (mediaKeyManager.micHistory.count > 3 && !isMicHistoryExpanded) {
                                            Divider().padding(.leading, 40)
                                        }
                                    }
                                    
                                    if mediaKeyManager.micHistory.count > 3 {
                                        Button(action: {
                                            withAnimation {
                                                isMicHistoryExpanded.toggle()
                                            }
                                        }) {
                                            Text(isMicHistoryExpanded ? "Show Less" : "Show All (\(mediaKeyManager.micHistory.count))")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.blue)
                                                .frame(maxWidth: .infinity, alignment: .center)
                                                .padding(.vertical, 10)
                                        }
                                        .buttonStyle(PlainButtonStyle())
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
                        
                        Divider()
                        
                        // Category 2: Camera Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Camera")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                            Text("Overlay Triggers")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.top, 10)
                                .padding(.bottom, 4)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 0) {
                                CustomSettingsRow(icon: "video.fill", iconColor: .blue, title: "Notify when Camera is ON", subtitle: "Show an overlay when the camera starts being used") {
                                    HStack(spacing: 8) { if mediaKeyManager.notifyOnCameraOn { SoundPickerControl(selectedSound: $mediaKeyManager.soundOnCameraOn) }
Toggle("", isOn: $mediaKeyManager.notifyOnCameraOn).labelsHidden() }
                               
                            }
                                Divider().padding(.leading, 48)
                                CustomSettingsRow(icon: "video.slash.fill", iconColor: .blue, title: "Notify when Camera is OFF", subtitle: "Show an overlay when the camera stops being used") {
                                    HStack(spacing: 8) { if mediaKeyManager.notifyOnCameraOff { SoundPickerControl(selectedSound: $mediaKeyManager.soundOnCameraOff) }
Toggle("", isOn: $mediaKeyManager.notifyOnCameraOff).labelsHidden() }
                               
                            }
                            }
                            .toggleStyle(.switch)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                            )
                            
                            Group {
                                if overlayPositionMode == "custom" {
                                Text("Overlay Position")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 10)
                                    .padding(.bottom, 4)
                                    .padding(.leading, 4)
                                
                                PositionPickerGroup(selection: $cameraOverlayPosition)
                                }
                            }
                                .padding(.bottom, 12)
                            
                            if !mediaKeyManager.cameraHistory.isEmpty {
                                let displayedHistory = isCameraHistoryExpanded ? mediaKeyManager.cameraHistory : Array(mediaKeyManager.cameraHistory.prefix(3))
                                
                                Text("Remembered cameras (\(mediaKeyManager.cameraHistory.count))")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 10)
                                    .padding(.bottom, 4)
                                    .padding(.leading, 4)
                                
                                VStack(spacing: 0) {
                                    ForEach(displayedHistory, id: \.self) { appName in
                                        let isBlocked = mediaKeyManager.cameraBlocklist.contains(appName)
                                        CustomSettingsRow(icon: "app", iconColor: isBlocked ? .gray : .blue, title: appName, subtitle: "Show notifications for this application", appNameForIcon: appName) {
                                            Toggle("", isOn: Binding(
                                                get: { !isBlocked },
                                                set: { isOn in
                                                    if isOn {
                                                        mediaKeyManager.cameraBlocklist.removeAll { $0 == appName }
                                                    } else {
                                                        if !mediaKeyManager.cameraBlocklist.contains(appName) {
                                                            mediaKeyManager.cameraBlocklist.append(appName)
                                                        }
                                                    }
                                                }
                                            )).labelsHidden()
                                        }
                                        
                                        if appName != displayedHistory.last || (mediaKeyManager.cameraHistory.count > 3 && !isCameraHistoryExpanded) {
                                            Divider().padding(.leading, 40)
                                        }
                                    }
                                    
                                    if mediaKeyManager.cameraHistory.count > 3 {
                                        Button(action: {
                                            withAnimation {
                                                isCameraHistoryExpanded.toggle()
                                            }
                                        }) {
                                            Text(isCameraHistoryExpanded ? "Show Less" : "Show All (\(mediaKeyManager.cameraHistory.count))")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.blue)
                                                .frame(maxWidth: .infinity, alignment: .center)
                                                .padding(.vertical, 10)
                                        }
                                        .buttonStyle(PlainButtonStyle())
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
                        
                        Divider()
                        
                        // Category 3: Location Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Location")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                            Text("Overlay Triggers")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.top, 10)
                                .padding(.bottom, 4)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 0) {
                                CustomSettingsRow(icon: "location.fill", iconColor: .blue, title: "Notify on Location Request", subtitle: "Show an overlay when location services are requested") {
                                    HStack(spacing: 8) { if mediaKeyManager.notifyOnLocationOn { SoundPickerControl(selectedSound: $mediaKeyManager.soundOnLocationOn) }
Toggle("", isOn: $mediaKeyManager.notifyOnLocationOn).labelsHidden() }
                               
                            }
                            }
                            .toggleStyle(.switch)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                            )
                            
                            Group {
                                if overlayPositionMode == "custom" {
                                Text("Overlay Position")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 10)
                                    .padding(.bottom, 4)
                                    .padding(.leading, 4)
                                
                                PositionPickerGroup(selection: $locationOverlayPosition)
                                }
                            }
                                .padding(.bottom, 12)
                            
                            Text("App Filters")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.top, 10)
                                .padding(.bottom, 4)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 0) {
                                CustomSettingsRow(icon: "gearshape", iconColor: .gray, title: "System Services", subtitle: "Diagnostic tools, background daemons") {
                                    Toggle("", isOn: $mediaKeyManager.locationShowSystemServices).labelsHidden()
                                }
                                Divider().padding(.leading, 40)
                                CustomSettingsRow(icon: "cloud.sun.fill", iconColor: .blue, title: "Weather", subtitle: "Apple Weather app & widgets") {
                                    Toggle("", isOn: $mediaKeyManager.locationShowWeather).labelsHidden()
                                }
                                Divider().padding(.leading, 40)
                                CustomSettingsRow(icon: "map.fill", iconColor: .green, title: "Maps", subtitle: "Apple Maps") {
                                    Toggle("", isOn: $mediaKeyManager.locationShowMaps).labelsHidden()
                                }
                                Divider().padding(.leading, 40)
                                CustomSettingsRow(icon: "safari.fill", iconColor: .blue, title: "Safari", subtitle: "Websites requesting location") {
                                    Toggle("", isOn: $mediaKeyManager.locationShowSafari).labelsHidden()
                                }
                                Divider().padding(.leading, 40)
                                CustomSettingsRow(icon: "app.dashed", iconColor: .purple, title: "Other Apps", subtitle: "Any other application") {
                                    Toggle("", isOn: $mediaKeyManager.locationShowOtherApps).labelsHidden()
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
            }
            .padding()
        }
    }
}
