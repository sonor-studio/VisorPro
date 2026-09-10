import SwiftUI

struct ColorPickerControl: View {
    @Binding var selectedColor: String
    let availableColors = OverlayColorManager.shared.availableColors
    @AppStorage("PremiumLicenseKey") private var savedLicenseKey = ""
    
    var body: some View {
        Menu {
            ForEach(availableColors, id: \.self) { color in
                Button(action: {
                    selectedColor = color
                }) {
                    Text(attributedText(for: color))
                }
            }
        } label: {
            HStack(spacing: 6) {
                if savedLicenseKey.isEmpty {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 10))
                }
                Circle()
                    .fill(OverlayColorManager.shared.parseColor(selectedColor))
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color(NSColor.separatorColor), lineWidth: 0.5))
                Text(selectedColor == "Default" ? "Default" : selectedColor)
            }
        }
        .fixedSize()
        .disabled(savedLicenseKey.isEmpty)
        .opacity(savedLicenseKey.isEmpty ? 0.6 : 1.0)
        .onAppear {
            if selectedColor == "Default" {
                selectedColor = "Blue"
            }
        }
    }
    
    private func attributedText(for colorName: String) -> AttributedString {
        let color = OverlayColorManager.shared.parseColor(colorName)
        var bullet = AttributedString("● ")
        bullet.foregroundColor = color
        bullet.font = .system(size: 16)
        bullet.strokeColor = .gray
        bullet.strokeWidth = -2.0
        
        let name = AttributedString(colorName == "Default" ? "Default" : colorName)
        return bullet + name
    }
}
