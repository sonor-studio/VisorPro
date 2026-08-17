import SwiftUI

struct BackgroundOptionButton: View {
    let title: String
    let isSelected: Bool
    let image: NSImage?
    let path: String?
    let color: NSColor?
    let isGradient: Bool
    let action: () -> Void
    
    var gradientColors: [Color] = [Color(red: 0.1, green: 0.1, blue: 0.1), Color(red: 0.3, green: 0.3, blue: 0.3)]
    
    var body: some View {
        Button(action: action) {
            VStack {
                ZStack {
                    if isGradient {
                        LinearGradient(gradient: Gradient(colors: gradientColors), startPoint: .leading, endPoint: .trailing)
                    } else if let p = path {
                        AsyncWallpaperImage(path: p)
                    } else if let img = image {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if let col = color {
                        Color(nsColor: col)
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(width: 80, height: 50)
                .clipped()
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 3 : 1)
                )
                
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
                    .frame(width: 80)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
