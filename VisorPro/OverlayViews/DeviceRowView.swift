import SwiftUI

struct DeviceRowView: View {
    let device: (id: UInt32, name: String)
    let isCurrent: Bool
    var tintColor: Color = .blue
    let onSelect: () -> Void
    @State private var isHovering: Bool = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(device.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer()
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(tintColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovering ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .transition(.identity)
        .onHoverExact { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovering = hovering }
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}
