import SwiftUI

struct DisplaySettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("displayOverlayPosition") private var displayOverlayPosition: String = "top"
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("displayAllowExpansion") private var displayAllowExpansion: Bool = true
    
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
                                DisplayOverlayView(isPreview: true, previewIsConnected: true).applyTheme(mediaKeyManager.overlayTheme)
                                    .scaleEffect(0.85)
                                DisplayOverlayView(isPreview: true, previewIsConnected: false).applyTheme(mediaKeyManager.overlayTheme)
                                    .scaleEffect(0.85)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Overlay Triggers")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                            .padding(.leading, 4)
                        
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "display.2", iconColor: .blue, title: "Monitor Connected", subtitle: "Show overlay when a new screen is plugged in") {
                                HStack(spacing: 8) { if mediaKeyManager.notifyOnDisplayConnect { SoundPickerControl(selectedSound: $mediaKeyManager.soundOnDisplayConnect) }
Toggle("", isOn: $mediaKeyManager.notifyOnDisplayConnect).labelsHidden() }
                           
                            }
                            Divider().padding(.leading, 48)
                            CustomSettingsRow(icon: "macwindow.badge.plus", iconColor: .blue, title: "Mode Change", subtitle: "Show overlay when switching between extend and mirror") {
                                HStack(spacing: 8) { if mediaKeyManager.notifyOnDisplayModeChange { SoundPickerControl(selectedSound: $mediaKeyManager.soundOnDisplayModeChange) }
Toggle("", isOn: $mediaKeyManager.notifyOnDisplayModeChange).labelsHidden() }
                           
                            }
                            Divider().padding(.leading, 48)
                            CustomSettingsRow(icon: "display", iconColor: .blue, title: "Monitor Disconnected", subtitle: "Show overlay when a screen is unplugged") {
                                HStack(spacing: 8) { if mediaKeyManager.notifyOnDisplayDisconnect { SoundPickerControl(selectedSound: $mediaKeyManager.soundOnDisplayDisconnect) }
Toggle("", isOn: $mediaKeyManager.notifyOnDisplayDisconnect).labelsHidden() }
                           
                            }
                        }
                        .toggleStyle(.switch)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                        )
                        
                        Text("Behavior")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.top, 10)
                            .padding(.bottom, 4)
                            .padding(.leading, 4)
                        
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "arrow.up.left.and.arrow.down.right", iconColor: .blue, title: "Allow Expansion", subtitle: "Allow overlay to expand and show display details") {
                                Toggle("", isOn: $displayAllowExpansion).labelsHidden()
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
                            
                            PositionPickerGroup(selection: $displayOverlayPosition)
                            }
                        }
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
