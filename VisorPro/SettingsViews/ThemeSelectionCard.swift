import SwiftUI

struct ThemeSelectionCard: View {
    let title: String
    let themeValue: String
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var resolvedScheme: ColorScheme {
        if themeValue == "dark" { return .dark }
        if themeValue == "light" { return .light }
        return colorScheme
    }
    
    var oppositeScheme: ColorScheme {
        return resolvedScheme == .dark ? .light : .dark
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                ZStack {
                    PreviewBackgroundView()
                        .environment(\.colorScheme, oppositeScheme)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    
                    UniversalOverlayView(
                        isPreview: true,
                        isExpanded: .constant(false),
                        showProgressBar: false,
                        progress: 0.0,
                        barColor: .clear,
                        fillCenter: false,
                        isMuted: false,
                        listHeight: 0,
                        customWidth: 160,
                        customHeight: 46,
                        supportDragGesture: false,
                        onDrag: nil,
                        baseContent: {
                            HStack {
                                Image(systemName: "paintpalette.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                Text("Preview")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                        },
                        expandedContent: { EmptyView() }
                    )
                    .allowsHitTesting(false)
                    .scaleEffect(0.8)
                    .environment(\.colorScheme, resolvedScheme)
                    .applyTheme(themeValue)
                }
                .padding(8)
                
                Divider()
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .primary)
                    .padding(.vertical, 10)
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
