import SwiftUI
import AppKit

struct ChangelogSettingsView: View {
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header Area
                HStack(alignment: .top, spacing: 16) {
                    if let appIcon = NSImage(named: NSImage.applicationIconName) {
                        Image(nsImage: appIcon)
                            .resizable()
                            .frame(width: 56, height: 56)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
                    } else {
                        Image(systemName: "app.fill")
                            .resizable()
                            .frame(width: 56, height: 56)
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Recent changes")
                            .font(.system(size: 22, weight: .bold))
                        
                        Text("Recent updates, new features, and improvements.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            
                        Text("Installed Version: \(appVersion)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                            .padding(.top, 2)
                    }
                    
                    Spacer()
                }
                .padding(.bottom, 16)
                
                Divider()
                    .padding(.bottom, 32)
                
                // Empty State Area
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.tertiary)
                    
                    Text("No Updates Yet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("We're currently working on the next release.\nCheck back later for release notes.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity)
                
            }
            .padding(32)
        }
        .navigationTitle("Changelog")
    }
}
