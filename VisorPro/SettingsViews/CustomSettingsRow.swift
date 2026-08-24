import SwiftUI

struct CustomSettingsRow<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    var appNameForIcon: String? = nil
    let content: () -> Content
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if let appName = appNameForIcon, let appPath = NSWorkspace.shared.fullPath(forApplication: appName) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: appPath))
                        .resizable()
                        .frame(width: 28, height: 28)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(gradient: Gradient(colors: [iconColor.opacity(0.1), iconColor.opacity(0.3)]), startPoint: .top, endPoint: .bottom))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(iconColor.opacity(0.9))
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            content()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
}
