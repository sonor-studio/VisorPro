import SwiftUI

struct SystemSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("showFanOverlay") private var showFanOverlay = true
    @AppStorage("fanOverlayPosition") private var fanOverlayPosition: String = "bottom"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 0) {
                    CustomSettingsRow(icon: "cpu", iconColor: .purple, title: "Enable System Module", subtitle: "When disabled, VisorPro will not show system and fan overlays") {
                        Toggle("", isOn: $showFanOverlay).labelsHidden()
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
                
                if showFanOverlay {
                    VStack(alignment: .center) {
                        Text("Preview")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ZStack {
                            PreviewBackgroundView()
                            
                            HStack(spacing: 20) {
                                FanOverlayView(isPreview: true, previewIsRunning: true)
                                    .scaleEffect(0.85)
                                FanOverlayView(isPreview: true, previewIsRunning: false)
                                    .scaleEffect(0.85)
                            }
                        }
                        .padding(.horizontal)
                        
                        Button("Test Fan Overlay") {
                            mediaKeyManager.triggerFanOverlay()
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 10)
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
                            CustomSettingsRow(icon: "fanblades", iconColor: .cyan, title: "Fan Started", subtitle: "Show overlay when fan starts running") {
                                Toggle("", isOn: $mediaKeyManager.notifyOnFanStart).labelsHidden()
                            }
                            if mediaKeyManager.notifyOnFanStart {
                                SoundPickerRow(selectedSound: $mediaKeyManager.soundOnFanStart)
                            }
                            Divider().padding(.leading, 48)
                            CustomSettingsRow(icon: "fanblades.slash", iconColor: .gray, title: "Fan Stopped", subtitle: "Show overlay when fan stops running") {
                                Toggle("", isOn: $mediaKeyManager.notifyOnFanStop).labelsHidden()
                            }
                            if mediaKeyManager.notifyOnFanStop {
                                SoundPickerRow(selectedSound: $mediaKeyManager.soundOnFanStop)
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
                        
                        Text("Overlay Position")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.top, 10)
                            .padding(.bottom, 4)
                            .padding(.leading, 4)
                        
                        HStack(spacing: 30) {
                            Spacer()
                            PositionPickerItem(title: "Top", isSelected: fanOverlayPosition == "top") {
                                fanOverlayPosition = "top"
                            }
                            PositionPickerItem(title: "Bottom", isSelected: fanOverlayPosition == "bottom") {
                                fanOverlayPosition = "bottom"
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .navigationTitle("System")
    }
}
