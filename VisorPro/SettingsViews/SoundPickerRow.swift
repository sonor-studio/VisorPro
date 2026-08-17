import SwiftUI

struct SoundPickerRow: View {
    @Binding var selectedSound: String
    
    var body: some View {
        HStack {
            Spacer()
            Image(systemName: "speaker.wave.2.fill")
                .foregroundColor(.secondary)
                .font(.system(size: 12))
            SoundPickerControl(selectedSound: $selectedSound)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .padding(.top, -6)
    }
}
