import SwiftUI

struct PositionPickerItem: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.2)))
                        .frame(width: 120, height: 80)
                    
                    // Ekranik z pillsem (nakładką)
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.5))
                        .frame(width: 40, height: 8)
                        .offset(y: title == "Top" ? -25 : 25)
                }
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
