import SwiftUI

struct SoundPickerControl: View {
    @Binding var selectedSound: String
    let availableSounds = ["None", "Default", "Power Chime", "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"]
    
    @State private var hasAppeared = false
    var body: some View {
        Picker("", selection: $selectedSound) {
            ForEach(availableSounds, id: \.self) { sound in
                Text(sound == "None" ? "None" : sound).tag(sound)
            }
        }
        .pickerStyle(MenuPickerStyle())
        .toggleStyle(DefaultToggleStyle())
        .labelsHidden()
        .frame(width: 130)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                hasAppeared = true
            }
        }
        .onChange(of: selectedSound) { _, newValue in
            if hasAppeared {
                MediaKeyManager.shared.playNotificationSound(named: newValue)
            }
        }
    }
}
