import SwiftUI
import AppKit

struct AboutSettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var licenseManager = LicenseManager.shared
    
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    
    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    if let appIcon = NSImage(named: NSImage.applicationIconName) {
                        Image(nsImage: appIcon)
                            .resizable()
                            .frame(width: 64, height: 64)
                            .cornerRadius(14)
                            .shadow(color: Color.black.opacity(0.1), radius: 3, y: 1)
                    } else {
                        Image(systemName: "app.fill")
                            .resizable()
                            .frame(width: 64, height: 64)
                            .foregroundColor(.blue)
                    }
                    
                    VStack(spacing: 4) {
                        Text("VisorPro")
                            .font(.system(size: 20, weight: .bold))
                        
                        Text("Version \(appVersion) • By Sonor Studio")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("VisorPro is an innovative tool for managing trackers and the system on macOS. Quick access, convenience, and full control over your device in one place.")
                        .font(.system(size: 13))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .foregroundColor(.primary.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            
            Section {
                LinkRow(icon: "cup.and.saucer.fill", title: "Buy Coffee", url: "https://buymeacoffee.com/sonorstudio")
                LinkRow(icon: "chevron.left.forwardslash.chevron.right", title: "Open GitHub", url: "https://github.com/sonor-studio/VisorPro")
            }
            
            Section {
                LinkRow(icon: "lock.shield.fill", title: "Privacy Policy", url: "https://github.com/sonor-studio/VisorPro/blob/main/PRIVACY_POLICY.md")
                LinkRow(icon: "doc.text.fill", title: "License", url: "https://github.com/sonor-studio/VisorPro/blob/main/LICENSE.txt")
                LinkRow(icon: "checkmark.shield.fill", title: "Security Policy", url: "https://github.com/sonor-studio/VisorPro/blob/main/SECURITY.md")
            }
            
            Section(header: Text("Registration").font(.system(size: 12, weight: .semibold))) {
                HStack {
                    Text("License Status")
                    Spacer()
                    if licenseManager.isPremium {
                        if licenseManager.isEarlyAdopter {
                            Text("Premium (Early Adopter)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.85))
                                .cornerRadius(6)
                        } else {
                            Text("Premium")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.blue.opacity(0.85))
                                .cornerRadius(6)
                        }
                    } else {
                        Text("Free Version")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.system(size: 13, weight: .medium))
                
                if let key = licenseManager.licenseKey {
                    HStack {
                        Text("License Key")
                        Spacer()
                        Text(key)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    .font(.system(size: 13, weight: .medium))
                }
                
                if let date = licenseManager.joinDate {
                    HStack {
                        Text("Join Date")
                        Spacer()
                        Text(date, style: .date)
                            .foregroundColor(.secondary)
                    }
                    .font(.system(size: 13, weight: .medium))
                }
            }
            
            Section(header: Text("Technical Information").font(.system(size: 12, weight: .semibold))) {
                HStack {
                    Text("App Version")
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(.secondary)
                }
                .font(.system(size: 13, weight: .medium))
                
                HStack {
                    Text("Build Number")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                        .foregroundColor(.secondary)
                }
                .font(.system(size: 13, weight: .medium))
                
                HStack {
                    Text("macOS Version")
                    Spacer()
                    Text(ProcessInfo.processInfo.operatingSystemVersionString)
                        .foregroundColor(.secondary)
                }
                .font(.system(size: 13, weight: .medium))
                
                ActionRow(icon: "doc.text.magnifyingglass", title: "Open Application Logs") {
                    LogManager.shared.openLogFile()
                }
            }
            
            Section {
                Text("© 2026 Sonor Studio. All rights reserved.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .listRowBackground(Color.clear)
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("About")
    }
}

struct LinkRow: View {
    let icon: String
    let title: String
    let url: String
    
    var body: some View {
        Button(action: {
            if let parsedUrl = URL(string: url) {
                NSWorkspace.shared.open(parsedUrl)
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                    .font(.system(size: 14))
                Text(title)
                    .foregroundColor(.primary)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 10))
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ActionRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                    .font(.system(size: 14))
                Text(title)
                    .foregroundColor(.primary)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
