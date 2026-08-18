import SwiftUI

struct KeyboardBrightnessSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("keyboardBrightnessOverlayPosition") private var keyboardBrightnessOverlayPosition: String = "top"
    @AppStorage("keyboardBrightnessFillCenter") private var keyboardBrightnessFillCenter: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
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
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "keyboard", iconColor: .orange, title: "Modifier Key", subtitle: "Hold this key while pressing F1/F2 to change keyboard brightness") {
                            Picker("", selection: $mediaKeyManager.keyboardBrightnessModifier) {
                                Text("Command ⌘").tag("command")
                                Text("Option ⌥").tag("option")
                                Text("Control ⌃").tag("control")
                            }
                            .frame(width: 140)
                        }
                        
                        Divider()
                            .padding(.leading, 50)
                            
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
                    .padding(.horizontal)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("Visual Style")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
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
                    
                    Text("Overlay Position")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                    
                    PositionPickerGroup(selection: $keyboardBrightnessOverlayPosition)
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
