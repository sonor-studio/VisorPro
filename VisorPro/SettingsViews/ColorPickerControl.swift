import SwiftUI

struct ColorPickerControl: View {
    @Binding var selectedColor: String
    let availableColors = OverlayColorManager.shared.availableColors
    
    var body: some View {
        Picker("", selection: $selectedColor) {
            ForEach(availableColors, id: \.self) { color in
                Text(color == "Default" ? "Default" : color).tag(color)
            }
        }
        .pickerStyle(MenuPickerStyle())
        .toggleStyle(DefaultToggleStyle())
        .labelsHidden()
        .frame(width: 130)
        .onAppear {
            if selectedColor == "Default" {
                selectedColor = "Blue"
            }
        }
    }
}
