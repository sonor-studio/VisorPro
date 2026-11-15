import SwiftUI

struct PermissionLockedView: View {
    let permissionType: String
    let icon: String
    let color: Color
    let title: String
    let description: String
    var isNotDetermined: Bool = false
    var isDenied: Bool = false
    var onGrantRequested: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.25), radius: 6, x: 0, y: 3)
                .padding(.bottom, 2)
            
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            Text(description)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 420)
            
            if !isDenied && onGrantRequested != nil {
                Button(action: {
                    onGrantRequested?()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.shield")
                        Text("Grant Permission")
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .padding(.top, 6)
            } else {
                Button(action: {
                    PermissionHelper.openPrivacySettings(for: permissionType)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape")
                        Text("Open System Settings")
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .padding(.top, 6)
            }
            
            Text("After granting permission, you may need to restart VisorPro to start using this overlay.")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
}

struct InlinePermissionCard: View {
    let permissionType: String
    let icon: String
    let color: Color
    let title: String
    let description: String
    var isNotDetermined: Bool = false
    var isDenied: Bool = false
    var onGrantRequested: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(description)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 8)
            
            if !isDenied && onGrantRequested != nil {
                Button(action: {
                    onGrantRequested?()
                }) {
                    Text("Grant Permission")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Button(action: {
                    PermissionHelper.openPrivacySettings(for: permissionType)
                }) {
                    Text("Open System Settings")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.2))
    }
}
