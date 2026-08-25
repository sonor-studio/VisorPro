import SwiftUI
import ApplicationServices
import Combine

struct WelcomeScreen: View {
    @AppStorage("hasCompletedWelcome") private var hasCompletedWelcome = false
    @State private var currentTab = UserDefaults.standard.bool(forKey: "hasCompletedWelcome") ? 1 : 0
    @State private var isTrusted = AXIsProcessTrusted()
    
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            if currentTab == 0 {
                firstScreen
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            } else {
                secondScreen
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            }
        }
        .frame(width: 500, height: 420)
        .onReceive(timer) { _ in
            if currentTab == 1 && !isTrusted {
                withAnimation(.spring()) {
                    isTrusted = AXIsProcessTrusted()
                }
            }
        }
    }
    
    var firstScreen: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 6) {
                Text("Welcome to VisorPro")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                
                Text("A new dimension of OSD notifications for macOS.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "bell.badge.fill", color: .blue, title: "Modern OSD", description: "Elegant notifications for volume, brightness, or battery status changes.")
                FeatureRow(icon: "slider.horizontal.3", color: .purple, title: "Full Customization", description: "Enable and disable features in Settings according to your needs.")
            }
            .padding(.horizontal, 40)
            
            Spacer(minLength: 16)
            
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    currentTab = 1
                }
            }) {
                Text("Continue")
                    .font(.headline)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    var secondScreen: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 70, height: 70)
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 6) {
                Text("Permissions Required")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                
                Text("For VisorPro to work correctly in the background and respond to system media keys, Accessibility permissions must be granted.")
                    .multilineTextAlignment(.center)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 40)
                
                Text("macOS requires these permissions to monitor function keys. Your data is completely secure.")
                    .multilineTextAlignment(.center)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 40)
            }
            
            VStack(spacing: 10) {
                if isTrusted {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 36))
                        Text("Permissions granted!")
                            .font(.headline)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    VStack(spacing: 8) {
                        Button(action: {
                            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                            _ = AXIsProcessTrustedWithOptions(options)
                            
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "gearshape.fill")
                                Text("Open System Settings")
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        
                        Text("Find VisorPro in System Settings and enable the toggle next to the app icon.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .transition(.opacity)
                }
            }
            .frame(minHeight: 90)
            
            Spacer(minLength: 10)
            
            HStack(spacing: 16) {
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentTab = 0
                    }
                }) {
                    Text("Back")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button(action: {
                    if hasCompletedWelcome {
                        hasCompletedWelcome = false
                        DispatchQueue.main.async {
                            hasCompletedWelcome = true
                        }
                    } else {
                        hasCompletedWelcome = true
                    }
                }) {
                    Text("Finish")
                        .font(.headline)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isTrusted)
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
