import SwiftUI

struct FocusSettingsView: View {
    @AppStorage("PremiumLicenseKey") private var savedLicenseKey = ""
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("focusOverlayPosition") private var focusOverlayPosition: String = "top"
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("focusDetailMode") private var focusDetailMode: Bool = false
    
    @State private var showFDAAlert: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Focus Module")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Text("Module Configuration")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                        
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "power", iconColor: .purple, title: "Enable Focus Module", subtitle: "When disabled, VisorPro will not show an overlay when Focus Mode changes") {
                            Toggle("", isOn: $mediaKeyManager.enableFocus).labelsHidden()
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

                if mediaKeyManager.enableFocus || savedLicenseKey.isEmpty {
                    VStack(alignment: .center) {
                        Text("Preview")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ZStack {
                            PreviewBackgroundView()
                            
                            HStack(spacing: -10) {
                                FocusOverlayView(isPreview: true, previewIsActive: true, previewModeName: "Do Not Disturb")
                                    .scaleEffect(0.85)
                                FocusOverlayView(isPreview: true, previewIsActive: false, previewModeName: "Do Not Disturb")
                                    .scaleEffect(0.85)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    Divider()
                    
                    if savedLicenseKey.isEmpty {
                        PremiumLockedView()
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Data Mode")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 4)
                                .padding(.leading, 4)
                                
                            VStack(spacing: 0) {
                                CustomSettingsRow(icon: "doc.text.magnifyingglass", iconColor: .purple, title: "Detailed Mode", subtitle: "Show exact Focus mode name (e.g. Work, Sleep). Requires Full Disk Access.") {
                                    Toggle("", isOn: Binding(
                                        get: { focusDetailMode },
                                        set: { newValue in
                                            if newValue && !PermissionHelper.hasFullDiskAccess() {
                                                showFDAAlert = true
                                            } else {
                                                focusDetailMode = newValue
                                            }
                                        }
                                    )).labelsHidden()
                                }
                            }
                            .toggleStyle(.switch)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                            )
                            
                            Text("Overlay Triggers")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 4)
                                .padding(.leading, 4)
                        
                            VStack(spacing: 0) {
                                CustomSettingsRow(icon: "moon.fill", iconColor: .purple, title: "Focus Mode On", subtitle: "Show overlay when Focus Mode is activated") {
                                    HStack(spacing: 8) { 
                                        if mediaKeyManager.notifyOnFocusOn { 
                                            SoundPickerControl(selectedSound: $mediaKeyManager.soundOnFocusOn) 
                                        }
                                        Toggle("", isOn: $mediaKeyManager.notifyOnFocusOn).labelsHidden() 
                                    }
                                }
                                Divider().padding(.leading, 48)
                                CustomSettingsRow(icon: "moon.zzz", iconColor: .purple, title: "Focus Mode Off", subtitle: "Show overlay when Focus Mode is deactivated") {
                                    HStack(spacing: 8) { 
                                        if mediaKeyManager.notifyOnFocusOff { 
                                            SoundPickerControl(selectedSound: $mediaKeyManager.soundOnFocusOff) 
                                        }
                                        Toggle("", isOn: $mediaKeyManager.notifyOnFocusOff).labelsHidden() 
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
                            
                            Text("Reminders")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 4)
                                .padding(.leading, 4)
                                
                            VStack(spacing: 0) {
                                CustomSettingsRow(icon: "bell.badge", iconColor: .purple, title: "Active Mode Reminder", subtitle: "Periodically remind you that Focus Mode is still active") {
                                    HStack(spacing: 8) {
                                        if mediaKeyManager.enableFocusReminder {
                                            Picker("", selection: $mediaKeyManager.focusReminderInterval) {
                                                Text("1 minute (test)").tag(1)
                                                Text("5 minutes").tag(5)
                                                Text("15 minutes").tag(15)
                                                Text("30 minutes").tag(30)
                                                Text("1 hour").tag(60)
                                            }
                                            .frame(width: 140)
                                            .labelsHidden()
                                        }
                                        Toggle("", isOn: $mediaKeyManager.enableFocusReminder).labelsHidden()
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
                        
                            Group {
                                if overlayPositionMode == "custom" {
                                    Text("Overlay Position")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 10)
                                
                                    PositionPickerGroup(selection: $focusOverlayPosition)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                } else {
                    DisabledModuleView(icon: "power", title: "Focus Module is Disabled", description: "Turn on the module to configure Focus overlays.")
                }
            }
        }
        .navigationTitle("Focus Mode")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .alert(isPresented: $showFDAAlert) {
            Alert(
                title: Text("Full Disk Access Required"),
                message: Text("To read the exact Focus Mode name from macOS, VisorPro needs Full Disk Access. Please enable it in System Settings > Privacy & Security > Full Disk Access."),
                primaryButton: .default(Text("Open Settings")) {
                    PermissionHelper.openPrivacySettings(for: "FullDisk")
                },
                secondaryButton: .cancel()
            )
        }
    }
}
