import SwiftUI

struct ColorPickerControl: View {
    @Binding var selectedColor: String
    let availableColors = OverlayColorManager.shared.availableColors
    
    var body: some View {
        Menu {
            ForEach(availableColors, id: \.self) { color in
                Button(action: {
                    selectedColor = color
                }) {
                    Label {
                        Text(color == "Default" ? "Default" : color)
                    } icon: {
                        Image(nsImage: createColorIcon(for: color))
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(nsImage: createColorIcon(for: selectedColor))
                Text(selectedColor == "Default" ? "Default" : selectedColor)
            }
        }
        .fixedSize()
        .onAppear {
            if selectedColor == "Default" {
                selectedColor = "Blue"
            }
        }
    }
    
    private func createColorIcon(for colorName: String) -> NSImage {
        let size = NSSize(width: 14, height: 14)
        let image = NSImage(size: size)
        image.lockFocus()
        
        // Use the manager to parse the color string into a SwiftUI Color,
        // but we need an NSColor.
        // Actually, we can get NSColor by hardcoding or looking it up.
        let nsColor: NSColor
        switch colorName {
        case "Blue": nsColor = .systemBlue
        case "Red": nsColor = .systemRed
        case "Green": nsColor = .systemGreen
        case "Yellow": nsColor = .systemYellow
        case "Orange": nsColor = .systemOrange
        case "Purple": nsColor = .systemPurple
        case "Pink": nsColor = NSColor(red: 0.85, green: 0.15, blue: 0.55, alpha: 1.0)
        case "Teal": nsColor = .systemTeal
        case "Indigo": nsColor = .systemIndigo
        default: nsColor = .systemBlue
        }
        
        nsColor.set()
        let path = NSBezierPath(ovalIn: NSRect(origin: .zero, size: size))
        path.fill()
        
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
