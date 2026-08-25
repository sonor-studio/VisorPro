import SwiftUI

struct SystemSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("showFanOverlay") private var showFanOverlay = true
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("fanOverlayPosition") private var fanOverlayPosition: String = "top"
    @AppStorage("ramOverlayPosition") private var ramOverlayPosition: String = "top"
    
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
                            
                            VStack(spacing: 20) {
                                HStack(spacing: 20) {
                                    FanOverlayView(isPreview: true, previewIsRunning: true).applyTheme(mediaKeyManager.overlayTheme)
                                        .scaleEffect(0.85)
                                    RamOverlayView(isPreview: true).applyTheme(mediaKeyManager.overlayTheme)
                                        .scaleEffect(0.85)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Fan")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 4)
                            
                        
                        Text("Overlay Triggers")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                            .padding(.leading, 20)
                        
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "fanblades", iconColor: .cyan, title: "Fan Started", subtitle: "Show overlay when fan starts running") {
                                HStack(spacing: 8) { if mediaKeyManager.notifyOnFanStart { SoundPickerControl(selectedSound: $mediaKeyManager.soundOnFanStart) }
Toggle("", isOn: $mediaKeyManager.notifyOnFanStart).labelsHidden() }
                           
                            }
                            Divider().padding(.leading, 48)
                            CustomSettingsRow(icon: "fanblades", iconColor: .gray, title: "Fan Stopped", subtitle: "Show overlay when fan stops running") {
                                HStack(spacing: 8) { if mediaKeyManager.notifyOnFanStop { SoundPickerControl(selectedSound: $mediaKeyManager.soundOnFanStop) }
Toggle("", isOn: $mediaKeyManager.notifyOnFanStop).labelsHidden() }
                           
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
                        
                        Group {
                            if overlayPositionMode == "custom" {
                            Text("Overlay Position")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.top, 10)
                                .padding(.bottom, 4)
                                .padding(.leading, 20)
                            
                            PositionPickerGroup(selection: $fanOverlayPosition)
                            }
                        }
                        .padding(.horizontal)
                        Divider()
                        
                        Text("RAM Alert")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 10)
                            .padding(.bottom, 4)
                            
                        
                        Text("Overlay Triggers")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                            .padding(.leading, 20)
                        
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "memorychip", iconColor: .red, title: "High RAM Usage", subtitle: "Show overlay when RAM usage is high") {
                                Toggle("", isOn: $mediaKeyManager.notifyOnHighRam).labelsHidden()
                            }
                            if mediaKeyManager.notifyOnHighRam {
                                SoundPickerRow(selectedSound: $mediaKeyManager.soundOnHighRam)
                                Divider().padding(.leading, 48)
                                HStack {
                                    Text("Threshold")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Slider(value: $mediaKeyManager.highRamThreshold, in: 80...100, step: 5)
                                        .frame(width: 150)
                                    Text("\(Int(mediaKeyManager.highRamThreshold))%")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .frame(width: 40, alignment: .trailing)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
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
                        
                        Group {
                            if overlayPositionMode == "custom" {
                            Text("RAM Overlay Position")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.top, 10)
                                .padding(.bottom, 4)
                                .padding(.leading, 20)
                            
                            PositionPickerGroup(selection: $ramOverlayPosition)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .navigationTitle("System")
    }
}
