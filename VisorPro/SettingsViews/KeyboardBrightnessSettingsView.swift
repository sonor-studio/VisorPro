import SwiftUI

struct KeyboardBrightnessSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("keyboardBrightnessOverlayPosition") private var keyboardBrightnessOverlayPosition: String = "top"
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("keyboardBrightnessFillCenter") private var keyboardBrightnessFillCenter: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Keyboard Brightness")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Text("Module Configuration")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                        
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "power", iconColor: .orange, title: "Enable Keyboard Brightness Module", subtitle: "When disabled, F1/F2 control screen brightness directly") {
                            Toggle("", isOn: $mediaKeyManager.enableKeyboardBrightness).labelsHidden()
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
                
                VStack(alignment: .center) {
                    Text("Preview")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ZStack {
                        PreviewBackgroundView()
                        
                        KeyboardBrightnessOverlayView(isPreview: true)
                            .scaleEffect(0.85)
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 20)
                
                Divider()
                
                if mediaKeyManager.enableKeyboardBrightness {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Modifier Key")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "keyboard", iconColor: .orange, title: "Modifier Key", subtitle: "Hold this key while pressing F1/F2 to change keyboard brightness") {
                                Picker("", selection: $mediaKeyManager.keyboardBrightnessModifier) {
                                    Text("Command ⌘").tag("command")
                                    Text("Option ⌥").tag("option")
                                    Text("Control ⌃").tag("control")
                                }
                                .frame(width: 140)
                            }
                        }
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sound Settings")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                            
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "speaker.wave.2.fill", iconColor: .orange, title: "Notification Sound", subtitle: "Select the sound to play when changing keyboard brightness") {
                                SoundPickerControl(selectedSound: $mediaKeyManager.soundOnKeyboardBrightness)
                            }
                        }
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Visual Style")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                        .padding(.leading, 4)
                    
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "paintpalette.fill", iconColor: .orange, title: "Fill Center", subtitle: "Fills the inside of the overlay with gray color instead of just the border") {
                            Toggle("", isOn: $keyboardBrightnessFillCenter).labelsHidden()
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
                        
                        PositionPickerGroup(selection: $keyboardBrightnessOverlayPosition)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .navigationTitle("Keyboard Brightness")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}
