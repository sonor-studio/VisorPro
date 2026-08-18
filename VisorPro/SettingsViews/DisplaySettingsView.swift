import SwiftUI

struct DisplaySettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("displayOverlayPosition") private var displayOverlayPosition: String = "bottom"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 0) {
                    CustomSettingsRow(icon: "display", iconColor: .blue, title: "Enable Displays Module", subtitle: "When disabled, VisorPro will not show overlays when external monitors are plugged in") {
                        Toggle("", isOn: $mediaKeyManager.enableDisplay).labelsHidden()
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
                
                if mediaKeyManager.enableDisplay {
                    VStack(alignment: .center) {
                        Text("Preview")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ZStack {
                            PreviewBackgroundView()
                            
                            HStack(spacing: -10) {
                                DisplayOverlayView(isPreview: true, previewIsConnected: true)
                                    .scaleEffect(0.85)
                                DisplayOverlayView(isPreview: true, previewIsConnected: false)
                                    .scaleEffect(0.85)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Overlay Triggers")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.bottom, 4)
                            .padding(.leading, 4)
                        
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "display.2", iconColor: .blue, title: "Monitor Connected", subtitle: "Show overlay when a new screen is plugged in") {
                                Toggle("", isOn: $mediaKeyManager.notifyOnDisplayConnect).labelsHidden()
                            }
                            if mediaKeyManager.notifyOnDisplayConnect {
                                SoundPickerRow(selectedSound: $mediaKeyManager.soundOnDisplayConnect)
                            }
                            Divider().padding(.leading, 48)
                            CustomSettingsRow(icon: "macwindow.badge.plus", iconColor: .blue, title: "Mode Change", subtitle: "Show overlay when switching between extend and mirror") {
                                Toggle("", isOn: $mediaKeyManager.notifyOnDisplayModeChange).labelsHidden()
                            }
                            if mediaKeyManager.notifyOnDisplayModeChange {
                                SoundPickerRow(selectedSound: $mediaKeyManager.soundOnDisplayModeChange)
                            }
                            Divider().padding(.leading, 48)
                            CustomSettingsRow(icon: "display", iconColor: .blue, title: "Monitor Disconnected", subtitle: "Show overlay when a screen is unplugged") {
                                Toggle("", isOn: $mediaKeyManager.notifyOnDisplayDisconnect).labelsHidden()
                            }
                            if mediaKeyManager.notifyOnDisplayDisconnect {
                                SoundPickerRow(selectedSound: $mediaKeyManager.soundOnDisplayDisconnect)
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
                        
                        PositionPickerGroup(selection: $displayOverlayPosition)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
        }
        .navigationTitle("Displays")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}
