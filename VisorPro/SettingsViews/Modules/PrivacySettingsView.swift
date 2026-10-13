import SwiftUI
import AVFoundation
import CoreLocation

struct PrivacySettingsView: View {
    @AppStorage("PremiumLicenseKey") private var savedLicenseKey = ""
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("micOverlayPosition") private var micOverlayPosition: String = "top"
    @AppStorage("micShowVisualizer") private var micShowVisualizer: Bool = false
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("cameraOverlayPosition") private var cameraOverlayPosition: String = "top"
    @AppStorage("locationOverlayPosition") private var locationOverlayPosition: String = "top"
    @AppStorage("micAllowExpansion") private var micAllowExpansion: Bool = true
    @AppStorage("cameraAllowExpansion") private var cameraAllowExpansion: Bool = true
    @State private var isMicHistoryExpanded: Bool = false
    @State private var isCameraHistoryExpanded: Bool = false
    @State private var isLocationHistoryExpanded: Bool = false
    @State private var showMicPermissionAlert: Bool = false
    @State private var showLocationPermissionAlert: Bool = false
    
    var body: some View {
        ModuleSettingsLayout(
            title: "Privacy",
            isEnabled: $mediaKeyManager.enablePrivacy,
            isPremium: true,
            preview: {
                HStack(alignment: .center, spacing: 20) {
                    MicOverlayView(isPreview: true, previewIsActive: true).applyTheme(mediaKeyManager.overlayTheme)
                        .frame(height: 56, alignment: .center)
                    
                    CameraOverlayView(isPreview: true, previewIsActive: true).applyTheme(mediaKeyManager.overlayTheme)
                        .frame(height: 56, alignment: .center)
                }
                .fixedSize(horizontal: true, vertical: false)
                .frame(height: 56, alignment: .center)
            },
            popovers: [
                ModulePopover(
                    icon: "mic.fill",
                    title: "Microphone",
                    content: AnyView(
                        Group {
                            if savedLicenseKey.isEmpty {
                                PremiumLockedView()
                            } else {
                                VStack(spacing: 0) {
                                    Text("TRIGGERS")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 16)
                                        .padding(.bottom, 8)
                                        
                                    CustomSettingsRow(icon: "mic.fill", iconColor: .blue, title: "Microphone is ON", subtitle: "Show an overlay when the microphone starts being used") {
                                        HStack(spacing: 8) { 
                                            if mediaKeyManager.notifyOnMicOn { 
                                                SoundPickerControl(selectedSound: $mediaKeyManager.soundOnMicOn) 
                                                if mediaKeyManager.overlayColorMode == "custom" { 
                                                    ColorPickerControl(selectedColor: $mediaKeyManager.colorOnMicOn) 
                                                } 
                                            }
                                            Toggle("", isOn: $mediaKeyManager.notifyOnMicOn).labelsHidden() 
                                        }
                                    }
                                    Divider().padding(.leading, 48)
                                    CustomSettingsRow(icon: "mic.slash.fill", iconColor: .blue, title: "Microphone is OFF", subtitle: "Show an overlay when the microphone stops being used") {
                                        HStack(spacing: 8) { 
                                            if mediaKeyManager.notifyOnMicOff { 
                                                SoundPickerControl(selectedSound: $mediaKeyManager.soundOnMicOff) 
                                            }
                                            Toggle("", isOn: $mediaKeyManager.notifyOnMicOff).labelsHidden() 
                                        }
                                    }
                                    Divider().padding(.leading, 48)
                                    CustomSettingsRow(icon: "arrow.up.left.and.arrow.down.right", iconColor: .blue, title: "Allow Expansion", subtitle: "Allow overlay to expand and show microphone details") {
                                        Toggle("", isOn: $micAllowExpansion).labelsHidden()
                                    }
                                    Text("VISUALIZER")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 16)
                                        .padding(.bottom, 8)
                                        
                                    CustomSettingsRow(icon: "waveform", iconColor: .blue, title: "Show Audio Waveform", subtitle: "Visualize microphone audio (Requires permission)") {
                                        Toggle("", isOn: Binding(
                                            get: { micShowVisualizer },
                                            set: { newValue in
                                                if newValue {
                                                    let status = AVCaptureDevice.authorizationStatus(for: .audio)
                                                    if status == .authorized {
                                                        micShowVisualizer = true
                                                    } else if status == .denied || status == .restricted {
                                                        micShowVisualizer = false
                                                        showMicPermissionAlert = true
                                                    } else {
                                                        micShowVisualizer = true
                                                        AVCaptureDevice.requestAccess(for: .audio) { granted in
                                                            DispatchQueue.main.async {
                                                                micShowVisualizer = granted
                                                                if !granted {
                                                                    showMicPermissionAlert = true
                                                                }
                                                            }
                                                        }
                                                    }
                                                } else {
                                                    micShowVisualizer = false
                                                }
                                            }
                                        )).labelsHidden()
                                    }
                                    
                                    if overlayPositionMode == "custom" {
                                        Text("POSITION")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 16)
                                            .padding(.top, 16)
                                            .padding(.bottom, 8)
                                            
                                        CustomSettingsRow(icon: "pip", iconColor: .blue, title: "Overlay Position", subtitle: "Position of microphone overlay") {
                                            PositionPickerGroup(selection: $micOverlayPosition)
                                        }
                                    }
                                    
                                    if !mediaKeyManager.micHistory.isEmpty {
                                        Text("APPLICATIONS")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 16)
                                            .padding(.top, 16)
                                            .padding(.bottom, 8)
                                            
                                        let displayedHistory = isMicHistoryExpanded ? mediaKeyManager.micHistory : Array(mediaKeyManager.micHistory.prefix(3))
                                        
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
                                }
                            }
                        }
                    )
                ),
                ModulePopover(
                    icon: "video.fill",
                    title: "Camera",
                    content: AnyView(
                        Group {
                            if savedLicenseKey.isEmpty {
                                PremiumLockedView()
                            } else {
                                VStack(spacing: 0) {
                                    CustomSettingsRow(icon: "video.fill", iconColor: .blue, title: "Camera is ON", subtitle: "Show an overlay when the camera starts being used") {
                                        HStack(spacing: 8) { 
                                            if mediaKeyManager.notifyOnCameraOn { 
                                                SoundPickerControl(selectedSound: $mediaKeyManager.soundOnCameraOn) 
                                                if mediaKeyManager.overlayColorMode == "custom" { 
                                                    ColorPickerControl(selectedColor: $mediaKeyManager.colorOnCameraOn) 
                                                } 
                                            }
                                            Toggle("", isOn: $mediaKeyManager.notifyOnCameraOn).labelsHidden() 
                                        }
                                    }
                                    Divider().padding(.leading, 48)
                                    CustomSettingsRow(icon: "video.slash.fill", iconColor: .blue, title: "Camera is OFF", subtitle: "Show an overlay when the camera stops being used") {
                                        HStack(spacing: 8) { 
                                            if mediaKeyManager.notifyOnCameraOff { 
                                                SoundPickerControl(selectedSound: $mediaKeyManager.soundOnCameraOff) 
                                            }
                                            Toggle("", isOn: $mediaKeyManager.notifyOnCameraOff).labelsHidden() 
                                        }
                                    }
                                    Divider().padding(.leading, 48)
                                    CustomSettingsRow(icon: "arrow.up.left.and.arrow.down.right", iconColor: .blue, title: "Allow Expansion", subtitle: "Allow overlay to expand and show camera details") {
                                        Toggle("", isOn: $cameraAllowExpansion).labelsHidden()
                                    }
                                    
                                    if overlayPositionMode == "custom" {
                                        Text("POSITION")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 16)
                                            .padding(.top, 16)
                                            .padding(.bottom, 8)
                                            
                                        CustomSettingsRow(icon: "pip", iconColor: .blue, title: "Overlay Position", subtitle: "Position of camera overlay") {
                                            PositionPickerGroup(selection: $cameraOverlayPosition)
                                        }
                                    }
                                    
                                    if !mediaKeyManager.cameraHistory.isEmpty {
                                        Text("APPLICATIONS")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 16)
                                            .padding(.top, 16)
                                            .padding(.bottom, 8)
                                            
                                        let displayedHistory = isCameraHistoryExpanded ? mediaKeyManager.cameraHistory : Array(mediaKeyManager.cameraHistory.prefix(3))
                                        
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
                                }
                            }
                        }
                    )
                ),
                ModulePopover(
                    icon: "location.fill",
                    title: "Location",
                    content: AnyView(
                        Group {
                            if savedLicenseKey.isEmpty {
                                PremiumLockedView()
                            } else {
                                VStack(spacing: 0) {
                                    Text("TRIGGERS")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 16)
                                        .padding(.bottom, 8)
                                        
                                    CustomSettingsRow(icon: "location.fill", iconColor: .blue, title: "Location Request", subtitle: "Show an overlay when location services are requested") {
                                        HStack(spacing: 8) { 
                                            if mediaKeyManager.notifyOnLocationOn { 
                                                SoundPickerControl(selectedSound: $mediaKeyManager.soundOnLocationOn) 
                                                if mediaKeyManager.overlayColorMode == "custom" { 
                                                    ColorPickerControl(selectedColor: $mediaKeyManager.colorOnLocationOn) 
                                                } 
                                            }
                                            Toggle("", isOn: Binding(
                                                get: { mediaKeyManager.notifyOnLocationOn },
                                                set: { newValue in
                                                    if newValue {
                                                        if PermissionHelper.isLocationNotDetermined() {
                                                            PermissionHelper.sharedLocationManager.requestAlwaysAuthorization()
                                                            mediaKeyManager.notifyOnLocationOn = true
                                                        } else if PermissionHelper.hasLocationPermission() {
                                                            mediaKeyManager.notifyOnLocationOn = true
                                                        } else {
                                                            DispatchQueue.main.async {
                                                                mediaKeyManager.notifyOnLocationOn = true
                                                                DispatchQueue.main.async {
                                                                    mediaKeyManager.notifyOnLocationOn = false
                                                                }
                                                            }
                                                            showLocationPermissionAlert = true
                                                        }
                                                    } else {
                                                        mediaKeyManager.notifyOnLocationOn = false
                                                    }
                                                }
                                            )).labelsHidden() 
                                        }
                                    }
                                    
                                    if overlayPositionMode == "custom" {
                                        Text("POSITION")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 16)
                                            .padding(.top, 16)
                                            .padding(.bottom, 8)
                                            
                                        CustomSettingsRow(icon: "pip", iconColor: .blue, title: "Overlay Position", subtitle: "Position of location overlay") {
                                            PositionPickerGroup(selection: $locationOverlayPosition)
                                        }
                                    }
                                    
                                    if !mediaKeyManager.locationHistory.isEmpty {
                                        Text("APPLICATIONS")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 16)
                                            .padding(.top, 16)
                                            .padding(.bottom, 8)
                                            
                                        let displayedHistory = isLocationHistoryExpanded ? mediaKeyManager.locationHistory : Array(mediaKeyManager.locationHistory.prefix(3))
                                        
                                        ForEach(displayedHistory, id: \.self) { appName in
                                            let isBlocked = mediaKeyManager.locationBlocklist.contains(appName)
                                            let iconName = appName == "System Services" ? "gearshape" : (appName == "Weather" ? "cloud.sun.fill" : (appName == "Maps" ? "map.fill" : (appName == "Safari" ? "safari.fill" : "app.dashed")))
                                            let iconColor = appName == "System Services" ? Color.gray : (appName == "Maps" ? Color.green : Color.blue)
                                            let subtitle = appName == "System Services" ? "Diagnostic tools, background daemons" : "Show notifications for this application"
                                            
                                            CustomSettingsRow(icon: iconName, iconColor: isBlocked ? .gray : iconColor, title: appName, subtitle: subtitle, appNameForIcon: appName) {
                                                Toggle("", isOn: Binding(
                                                    get: { !isBlocked },
                                                    set: { isOn in
                                                        if isOn {
                                                            mediaKeyManager.locationBlocklist.removeAll { $0 == appName }
                                                        } else {
                                                            if !mediaKeyManager.locationBlocklist.contains(appName) {
                                                                mediaKeyManager.locationBlocklist.append(appName)
                                                            }
                                                        }
                                                    }
                                                )).labelsHidden()
                                            }
                                        }
                                        
                                        if mediaKeyManager.locationHistory.count > 3 {
                                            Button(action: {
                                                withAnimation {
                                                    isLocationHistoryExpanded.toggle()
                                                }
                                            }) {
                                                Text(isLocationHistoryExpanded ? "Show Less" : "Show All (\(mediaKeyManager.locationHistory.count))")
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(.blue)
                                                    .frame(maxWidth: .infinity, alignment: .center)
                                                    .padding(.vertical, 10)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                }
                            }
                        }
                    )
                )
            ]
        )
        .navigationTitle("Privacy")
        .alert(isPresented: $showMicPermissionAlert) {
            Alert(
                title: Text("Microphone Access Required"),
                message: Text("To display the audio waveform, VisorPro needs microphone access. Please enable it in System Settings > Privacy & Security > Microphone."),
                primaryButton: .default(Text("Open Settings")) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                        NSWorkspace.shared.open(url)
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .alert(isPresented: $showLocationPermissionAlert) {
            Alert(
                title: Text("Location Access Required"),
                message: Text("To monitor location services usage, VisorPro needs location access. Please enable it in System Settings > Privacy & Security > Location Services."),
                primaryButton: .default(Text("Open Settings")) {
                    PermissionHelper.openPrivacySettings(for: "Location")
                },
                secondaryButton: .cancel()
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LocationAuthorizationChanged"))) { _ in
            if mediaKeyManager.notifyOnLocationOn && !PermissionHelper.hasLocationPermission() && !PermissionHelper.isLocationNotDetermined() {
                DispatchQueue.main.async {
                    mediaKeyManager.notifyOnLocationOn = true
                    DispatchQueue.main.async {
                        mediaKeyManager.notifyOnLocationOn = false
                    }
                }
                showLocationPermissionAlert = true
            }
        }
    }
}
