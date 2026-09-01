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
                if let appName = appNameForIcon, 
                   let appPath = NSWorkspace.shared.perform(NSSelectorFromString("fullPathForApplication:"), with: appName)?.takeUnretainedValue() as? String {
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
import SwiftUI

struct DisabledModuleView: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .regular))
                .foregroundColor(.secondary.opacity(0.5))
                .padding(.bottom, 8)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
        .padding()
    }
}
