import SwiftUI

struct SoundPickerControl: View {
    @Binding var selectedSound: String
    let availableSounds = ["None", "Default", "Power Chime", "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"]
    
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
        .onChange(of: selectedSound) { _, newValue in
            MediaKeyManager.shared.playNotificationSound(named: newValue)
        }
    }
}
