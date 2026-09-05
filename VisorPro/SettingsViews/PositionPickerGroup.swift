import SwiftUI

struct PositionPickerGroup: View {
    @Binding var selection: String
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                Spacer()
                PositionPickerItem(title: "Top Left", position: "top_left", selection: $selection)
                Spacer()
                PositionPickerItem(title: "Top Center", position: "top", selection: $selection)
                Spacer()
                PositionPickerItem(title: "Top Right", position: "top_right", selection: $selection)
                Spacer()
            }
            HStack(spacing: 0) {
                Spacer()
                PositionPickerItem(title: "Bottom Left", position: "bottom_left", selection: $selection)
                Spacer()
                PositionPickerItem(title: "Bottom Center", position: "bottom", selection: $selection)
                Spacer()
                PositionPickerItem(title: "Bottom Right", position: "bottom_right", selection: $selection)
                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}
