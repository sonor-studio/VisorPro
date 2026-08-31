import SwiftUI

struct SystemSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("showSystemModule") private var showSystemModule = true
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("ramOverlayPosition") private var ramOverlayPosition: String = "top"
    @AppStorage("cpuOverlayPosition") private var cpuOverlayPosition: String = "top"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 0) {
                    CustomSettingsRow(icon: "cpu", iconColor: .purple, title: "Enable System Module", subtitle: "When disabled, VisorPro will not show system overlays") {
                        Toggle("", isOn: $showSystemModule).labelsHidden()
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
                
                if showSystemModule {
                    VStack(alignment: .center) {
                        Text("Preview")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ZStack {
                            PreviewBackgroundView()
                            
                            VStack(spacing: 20) {
                                HStack(spacing: 20) {
                                    CpuTemperatureOverlayView(isPreview: true).applyTheme(mediaKeyManager.overlayTheme)
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
                        Text("CPU Alert")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 10)
                            .padding(.bottom, 4)
                            
                        Text("Overlay Triggers")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                            .padding(.leading, 20)
                        
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "thermometer", iconColor: .orange, title: "High CPU Temp", subtitle: "Show overlay when CPU temperature is high") {
                                HStack(spacing: 8) {
                                    if mediaKeyManager.notifyOnHighCpuTemp {
                                        SoundPickerControl(selectedSound: $mediaKeyManager.soundOnHighCpuTemp)
                                    }
                                    Toggle("", isOn: $mediaKeyManager.notifyOnHighCpuTemp).labelsHidden()
                                }
                            }
                            if mediaKeyManager.notifyOnHighCpuTemp {
                                Divider().padding(.leading, 48)
                                HStack {
                                    Text("Threshold")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Slider(value: $mediaKeyManager.highCpuTempThreshold, in: 60...100, step: 5)
                                        .frame(width: 150)
                                    Text("\(Int(mediaKeyManager.highCpuTempThreshold))°C")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .frame(width: 45, alignment: .trailing)
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
                            Text("CPU Overlay Position")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.top, 10)
                                .padding(.bottom, 4)
                                .padding(.leading, 20)
                            
                            PositionPickerGroup(selection: $cpuOverlayPosition)
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
                                HStack(spacing: 8) {
                                    if mediaKeyManager.notifyOnHighRam {
                                        SoundPickerControl(selectedSound: $mediaKeyManager.soundOnHighRam)
                                    }
                                    Toggle("", isOn: $mediaKeyManager.notifyOnHighRam).labelsHidden()
                                }
                            }
                            if mediaKeyManager.notifyOnHighRam {
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
