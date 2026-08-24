import SwiftUI

struct PositionPickerItem: View {
    let title: String
    let position: String
    @Binding var selection: String
    
    private var isSelected: Bool {
        selection == position
    }
    
    var body: some View {
        Button(action: {
            selection = position
        }) {
            VStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.2)))
                        .frame(width: 80, height: 50)
                    
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.5))
                        .frame(width: 24, height: 6)
                        .offset(x: offsetX, y: offsetY)
                }
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var offsetX: CGFloat {
        if position.hasSuffix("_left") { return -15 }
        if position.hasSuffix("_right") { return 15 }
        return 0
    }
    
    private var offsetY: CGFloat {
        if position.hasPrefix("top") { return -15 }
        if position.hasPrefix("bottom") { return 15 }
        return 0
    }
}
