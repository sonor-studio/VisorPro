import SwiftUI

// MARK: - Triangle Arrow Shape
/// A triangle pointing towards the anchor button.
struct TriangleArrow: Shape {
    var direction: Edge
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch direction {
        case .top:
            path.move(to: CGPoint(x: rect.midX - 8, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX + 8, y: rect.maxY))
        case .bottom:
            path.move(to: CGPoint(x: rect.midX - 8, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX + 8, y: rect.minY))
        case .leading:
            path.move(to: CGPoint(x: rect.maxX, y: rect.midY - 8))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY + 8))
        case .trailing:
            path.move(to: CGPoint(x: rect.minX, y: rect.midY - 8))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY + 8))
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Popover Menu View
/// A floating popover panel with a triangle indicator pointing toward the anchor.
struct PopoverMenuView<Content: View>: View {
    let arrowEdge: Edge
    @Environment(\.colorScheme) var colorScheme
    @ViewBuilder var content: () -> Content
    
    private var bgColor: Color {
        colorScheme == .dark
            ? Color(white: 0.14, opacity: 0.95)
            : Color(white: 0.96, opacity: 0.95)
    }
    
    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.08)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if arrowEdge == .top {
                TriangleArrow(direction: .top)
                    .fill(bgColor)
                    .frame(width: 20, height: 10)
                    .overlay(
                        TriangleArrow(direction: .top)
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .zIndex(1)
            }
            
            HStack(spacing: 0) {
                if arrowEdge == .leading {
                    TriangleArrow(direction: .leading)
                        .fill(bgColor)
                        .frame(width: 10, height: 20)
                        .overlay(
                            TriangleArrow(direction: .leading)
                                .stroke(borderColor, lineWidth: 1)
                        )
                        .zIndex(1)
                }
                
                content()
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(bgColor)
                            .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    )
                
                if arrowEdge == .trailing {
                    TriangleArrow(direction: .trailing)
                        .fill(bgColor)
                        .frame(width: 10, height: 20)
                        .overlay(
                            TriangleArrow(direction: .trailing)
                                .stroke(borderColor, lineWidth: 1)
                        )
                        .zIndex(1)
                }
            }
            
            if arrowEdge == .bottom {
                TriangleArrow(direction: .bottom)
                    .fill(bgColor)
                    .frame(width: 20, height: 10)
                    .overlay(
                        TriangleArrow(direction: .bottom)
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .zIndex(1)
            }
        }
    }
}

struct InteractiveGlassButtonStyle: ButtonStyle {
    var isActive: Bool
    var tintColor: Color = .accentColor
    
    func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 26.0, *) {
            configuration.label
                .foregroundColor(isActive ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isActive ? tintColor.opacity(0.8) : Color.clear, in: .capsule)
                .glassEffect(.regular, in: .capsule)
                .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
        } else {
            configuration.label
                .foregroundColor(isActive ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isActive ? tintColor : Color.clear)
                )
                .background(.regularMaterial, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
        }
    }
}

// MARK: - Floating Action Button
/// A compact pill button used as an anchor for popover menus.
struct FloatingActionButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .buttonStyle(InteractiveGlassButtonStyle(isActive: isActive))
    }
}
