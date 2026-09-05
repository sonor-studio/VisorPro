import SwiftUI
import WebKit
import AppKit

struct PremiumSettingsView: View {
    @State private var showingCheckout = false
    @State private var showingActivation = false
    @StateObject private var licenseManager = PolarLicenseManager()
    
    @AppStorage("PremiumLicenseKey") private var savedLicenseKey = ""
    @AppStorage("licenseActivationDate") private var activationDate = ""


    private var buyButton: some View {
        Button(action: { showingCheckout = true }) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                Text("Get Premium")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.black)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // HERO CARD
                VStack(alignment: .leading, spacing: 12) {
                    
                    if savedLicenseKey.isEmpty {
                        // Header
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                                .padding(8)
                                .background(Color.green)
                                .cornerRadius(8)
                            
                            Text("VISORPRO PREMIUM")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .tracking(1.5)
                        }
                        
                        // Slogan
                        Text("Your workspace, unleashed.")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundColor(.primary)
                            .padding(.top, 4)
                        
                        // Description
                        Text("Elevate your Mac experience with pro-level trackers, multi-display support, and absolute freedom over your overlays.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                            .padding(.trailing, 40)
                            .padding(.bottom, 6)
                        
                        // Features Row
                        HStack(spacing: 16) {
                            FeatureBadge(icon: "creditcard", text: "Single purchase")
                            FeatureBadge(icon: "infinity", text: "Lifetime validity")
                            FeatureBadge(icon: "arrow.triangle.2.circlepath", text: "All future updates")
                        }
                        .padding(.vertical, 8)
                        
                        // Buy Button & Activation
                        VStack(alignment: .leading, spacing: 8) {
                            buyButton
                            
                            Text("One-time payment • Secure checkout")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 6)
                        
                        // Already have a key
                        Button(action: {
                            showingActivation = true
                        }) {
                            Text("I already have a license key")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .underline()
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.top, 12)
                        
                    } else {
                        // ACTIVE LICENSE VIEW
                        VStack(alignment: .leading, spacing: 20) {
                            // Header
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.green)
                                    .shadow(color: Color.green.opacity(0.3), radius: 5, x: 0, y: 3)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("VisorPro Premium")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.primary)
                                    
                                    Text("License is currently active on this Mac.")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Divider()
                                .opacity(0.5)
                            
                            // Info Grid
                            VStack(spacing: 12) {
                                LicenseInfoRow(title: "Plan", value: "Lifetime License", icon: "infinity")
                                LicenseInfoRow(title: "Status", value: "Active", icon: "checkmark.circle.fill", valueColor: .green)
                                LicenseInfoRow(title: "Updates", value: "Included", icon: "arrow.triangle.2.circlepath")
                                if !activationDate.isEmpty {
                                    LicenseInfoRow(title: "Activated", value: activationDate, icon: "calendar")
                                }
                            }
                            .padding(.vertical, 4)
                            
                            // Key Field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("License Key")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Text(savedLicenseKey)
                                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                                        .foregroundColor(.primary)
                                        // No truncation, let it wrap or scale
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.8)
                                    
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                                )
                            }
                            
                            HStack {
                                Text("Thank you for supporting VisorPro!")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button(action: {
                                    savedLicenseKey = ""
                                }) {
                                    Text("Deactivate License")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                )
                
                // EXTRA FEATURES SECTION
                VStack(alignment: .leading, spacing: 16) {
                    Text("What's included in Premium")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    // Grid
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 24), GridItem(.flexible(), spacing: 24)], spacing: 32) {
                        
                        WidgetPreviewCard(
                            title: "Multimedia Tracker",
                            description: "Control your music, podcasts, and other media with beautiful playback overlays.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.05))
                                
                                HStack(spacing: 12) {
                                    // Abstract album art
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.blue.opacity(0.2))
                                        .frame(width: 36, height: 36)
                                        .overlay(Image(systemName: "music.note").foregroundColor(.blue.opacity(0.6)))
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.blue.opacity(0.5))
                                            .frame(width: 50, height: 6)
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.blue.opacity(0.3))
                                            .frame(width: 30, height: 6)
                                    }
                                    
                                    Image(systemName: "play.fill")
                                        .foregroundColor(.blue.opacity(0.7))
                                        .font(.system(size: 14))
                                        .padding(.leading, 4)
                                }
                                .padding(14)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                            }
                        )
                        
                        WidgetPreviewCard(
                            title: "Storage Tracker",
                            description: "Monitor your disk space and get alerts when storage is low.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.purple.opacity(0.05))
                                
                                HStack(spacing: 16) {
                                    // Abstract pie/ring chart for disk usage
                                    ZStack {
                                        Circle().stroke(Color.purple.opacity(0.2), lineWidth: 5).frame(width: 36, height: 36)
                                        Circle().trim(from: 0, to: 0.85).stroke(Color.purple, style: StrokeStyle(lineWidth: 5, lineCap: .round)).frame(width: 36, height: 36).rotationEffect(.degrees(-90))
                                        Image(systemName: "internaldrive").font(.system(size: 14)).foregroundColor(.purple)
                                    }
                                    
                                    // Abstract Text Lines
                                    VStack(alignment: .leading, spacing: 6) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.purple.opacity(0.6))
                                            .frame(width: 45, height: 6)
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.secondary.opacity(0.4))
                                            .frame(width: 25, height: 4)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                            }
                        )
                        
                        WidgetPreviewCard(
                            title: "Bluetooth Tracker",
                            description: "Monitor connectivity and battery of AirPods and other devices.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.indigo.opacity(0.05))
                                
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle().fill(Color.indigo.opacity(0.1)).frame(width: 36, height: 36)
                                        Image(systemName: "airpodsmax")
                                            .foregroundColor(.indigo)
                                            .font(.system(size: 16))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.indigo.opacity(0.6))
                                            .frame(width: 45, height: 6)
                                        
                                        HStack(spacing: 4) {
                                            Circle().fill(Color.green).frame(width: 6, height: 6)
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color.secondary.opacity(0.4))
                                                .frame(width: 30, height: 4)
                                        }
                                    }
                                }
                                .padding(12)
                                .frame(width: 140)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                            }
                        )
                        
                        WidgetPreviewCard(
                            title: "Privacy Tracker",
                            description: "Know instantly when your camera, mic, or location is accessed.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green.opacity(0.05))
                                
                                HStack(spacing: -12) {
                                    ZStack {
                                        Circle().fill(Color(NSColor.controlBackgroundColor)).frame(width: 46, height: 46)
                                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                                        Circle().fill(Color.green).frame(width: 34, height: 34)
                                        Image(systemName: "video.fill").font(.system(size: 14)).foregroundColor(.white)
                                    }.zIndex(3)
                                    
                                    ZStack {
                                        Circle().fill(Color(NSColor.controlBackgroundColor)).frame(width: 46, height: 46)
                                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                                        Circle().fill(Color.orange).frame(width: 34, height: 34)
                                        Image(systemName: "mic.fill").font(.system(size: 14)).foregroundColor(.white)
                                    }.zIndex(2)
                                    
                                    ZStack {
                                        Circle().fill(Color(NSColor.controlBackgroundColor)).frame(width: 46, height: 46)
                                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                                        Circle().fill(Color.blue).frame(width: 34, height: 34)
                                        Image(systemName: "location.fill").font(.system(size: 14)).foregroundColor(.white)
                                    }.zIndex(1)
                                }
                            }
                        )
                        
                        WidgetPreviewCard(
                            title: "System Tracker",
                            description: "Monitor your real-time memory usage and performance stats.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.orange.opacity(0.05))
                                
                                HStack(spacing: 16) {
                                    // Abstract circular graph
                                    ZStack {
                                        Circle().stroke(Color.orange.opacity(0.2), lineWidth: 5).frame(width: 36, height: 36)
                                        Circle().trim(from: 0, to: 0.65).stroke(Color.orange, style: StrokeStyle(lineWidth: 5, lineCap: .round)).frame(width: 36, height: 36).rotationEffect(.degrees(-90))
                                        Image(systemName: "memorychip").font(.system(size: 14)).foregroundColor(.orange)
                                    }
                                    
                                    // Abstract bar graph
                                    VStack(alignment: .leading, spacing: 5) {
                                        RoundedRectangle(cornerRadius: 2).fill(Color.orange.opacity(0.8)).frame(width: 45, height: 5)
                                        RoundedRectangle(cornerRadius: 2).fill(Color.orange.opacity(0.5)).frame(width: 35, height: 5)
                                        RoundedRectangle(cornerRadius: 2).fill(Color.orange.opacity(0.3)).frame(width: 50, height: 5)
                                    }
                                }
                                .padding(.vertical, 14).padding(.horizontal, 16)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                            }
                        )
                        
                        WidgetPreviewCard(
                            title: "Wi-Fi Tracker",
                            description: "Monitor your network connection status and speed.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.cyan.opacity(0.05))
                                
                                VStack(spacing: 12) {
                                    Image(systemName: "wifi")
                                        .font(.system(size: 24))
                                        .foregroundColor(.cyan)
                                    
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.down").font(.system(size: 10)).foregroundColor(.green)
                                        RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.3)).frame(width: 25, height: 4)
                                        
                                        Image(systemName: "arrow.up").font(.system(size: 10)).foregroundColor(.blue)
                                        RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.3)).frame(width: 20, height: 4)
                                    }
                                }
                                .padding(12)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                            }
                        )
                        
                        WidgetPreviewCard(
                            title: "Theme Tracker",
                            description: "Get instantly notified when your system appearance changes.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.primary.opacity(0.02))
                                
                                HStack(spacing: 20) {
                                    Image(systemName: "sun.max.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.orange)
                                    
                                    // Abstract toggle
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.secondary.opacity(0.2)).frame(width: 50, height: 26)
                                        Circle().fill(Color(NSColor.windowBackgroundColor)).frame(width: 20, height: 20).shadow(color: .black.opacity(0.2), radius: 2, y: 1).offset(x: 28)
                                    }
                                    
                                    Image(systemName: "moon.stars.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.indigo)
                                }
                            }
                        )
                        
                        WidgetPreviewCard(
                            title: "Display Tracker",
                            description: "Stay informed about your external displays and monitor connections.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.teal.opacity(0.05))
                                
                                VStack(spacing: 8) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.teal, lineWidth: 2)
                                            .frame(width: 60, height: 40)
                                        RoundedRectangle(cornerRadius: 1)
                                            .fill(Color.teal.opacity(0.3))
                                            .frame(width: 20, height: 3)
                                            .offset(y: 20)
                                    }
                                    
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.teal.opacity(0.2)).frame(width: 80, height: 6)
                                        Capsule().fill(Color.teal).frame(width: 50, height: 6)
                                        Circle().fill(Color.white).frame(width: 10, height: 10).shadow(radius: 1).offset(x: 45)
                                    }
                                }
                                .padding(12)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                            }
                        )
                        
                        WidgetPreviewCard(
                            title: "More Overlays",
                            description: "Display up to 5 active tracker notifications on your screen simultaneously.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.pink.opacity(0.05))
                                
                                VStack(spacing: -12) {
                                    // Top capsule
                                    HStack(spacing: 6) {
                                        Circle().fill(Color.pink.opacity(0.7)).frame(width: 10, height: 10)
                                        RoundedRectangle(cornerRadius: 2).fill(Color.pink.opacity(0.3)).frame(width: 40, height: 4)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Color(NSColor.controlBackgroundColor)).cornerRadius(8)
                                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                                    .scaleEffect(0.85).opacity(0.5)
                                    .zIndex(1)
                                    
                                    // Middle capsule
                                    HStack(spacing: 6) {
                                        Circle().fill(Color.teal.opacity(0.7)).frame(width: 12, height: 12)
                                        RoundedRectangle(cornerRadius: 2).fill(Color.teal.opacity(0.3)).frame(width: 50, height: 4)
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Color(NSColor.controlBackgroundColor)).cornerRadius(8)
                                    .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
                                    .scaleEffect(0.95).opacity(0.8)
                                    .zIndex(2)
                                    
                                    // Front capsule
                                    HStack(spacing: 8) {
                                        Image(systemName: "square.3.layers.3d").foregroundColor(.indigo).font(.system(size: 14))
                                        RoundedRectangle(cornerRadius: 2).fill(Color.indigo.opacity(0.4)).frame(width: 60, height: 4)
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .background(Color(NSColor.controlBackgroundColor)).cornerRadius(8)
                                    .shadow(color: .black.opacity(0.15), radius: 5, y: 3)
                                    .zIndex(3)
                                }
                                .offset(y: 4)
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
                
                Spacer(minLength: 20)
            }
            .padding(24)
        }
        // Usunięto sztywne białe tło, żeby widok przejmował przezroczystość z SettingsView
        .background(Color.clear)
        .sheet(isPresented: $showingCheckout) {
            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        NSWorkspace.shared.open(URL(string: "https://buy.polar.sh/polar_cl_PInjogqryIOSYRz17wX36JqBy15auEMjHYREM1Gspct")!)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "safari")
                            Text("Open in Browser")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading, 20)
                    .help("Open in Safari for Apple Pay support")
                    
                    Spacer()
                    Button(action: { showingCheckout = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding()
                }
                .background(Color(NSColor.controlBackgroundColor))
                Divider()
                CheckoutWebView(url: URL(string: "https://buy.polar.sh/polar_cl_PInjogqryIOSYRz17wX36JqBy15auEMjHYREM1Gspct")!)
            }
            .frame(width: 600, height: 600)
        }
        .sheet(isPresented: $showingActivation) {
            ActivationPopupView(
                isPresented: $showingActivation,
                licenseManager: licenseManager,
                savedLicenseKey: $savedLicenseKey
            )
        }
    }
}

// MARK: - Popup View dla Aktywacji

struct ActivationPopupView: View {
    @Binding var isPresented: Bool
    @ObservedObject var licenseManager: PolarLicenseManager
    @Binding var savedLicenseKey: String
    
    @AppStorage("licenseActivationDate") private var activationDate = ""
    @State private var inputKey = ""
    

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Activate License")
                    .font(.headline)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Text("Enter the license key you received after purchase.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            HStack {
                TextField("EA-XYZ-...", text: $inputKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(.body, design: .monospaced))
                
                Button(action: {
                    if let clipboard = NSPasteboard.general.string(forType: .string) {
                        inputKey = clipboard
                    }
                }) {
                    Image(systemName: "doc.on.clipboard")
                }
                .help("Paste from clipboard")
            }
            
            if let error = licenseManager.errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }
            
            HStack {
                Link("Lost your key?", destination: URL(string: "https://polar.sh/sonor-studio/portal/request")!)
                    .font(.system(size: 11))
                Spacer()
                
                Button(action: {
                    Task {
                        let cleanKey = inputKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        let isValid = await licenseManager.validateKey(key: cleanKey)
                        if isValid {
                            savedLicenseKey = cleanKey
                            if activationDate.isEmpty {
                                let formatter = DateFormatter()
                                formatter.dateStyle = .long
                                formatter.timeStyle = .none
                                activationDate = formatter.string(from: Date())
                            }
                            isPresented = false
                        }
                    }
                }) {
                    if licenseManager.isLoading {
                        ProgressView().controlSize(.small)
                            .frame(width: 60)
                    } else {
                        Text("Activate")
                            .frame(width: 60)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputKey.isEmpty || licenseManager.isLoading)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}

// MARK: - Components

struct FeatureBadge: View {
    let icon: String
    let text: String
    

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(.secondary)
    }
}


struct WidgetPreviewCard<Preview: View>: View {
    let title: String
    let description: String
    let preview: Preview
    

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Preview Area
            ZStack {
                Color(NSColor.controlBackgroundColor).opacity(0.4)
                
                preview
            }
            .frame(height: 140)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
            )
            
            // Text Area
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)
        }
    }
}


// Prosty wrapper WKWebView
struct CheckoutWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
    }
}

struct PremiumLockModifier: ViewModifier {
    let isPremium: Bool
    
    func body(content: Content) -> some View {
        if isPremium {
            content
        } else {
            content
                .disabled(true)
                .overlay(
                    ZStack {
                        Color(NSColor.windowBackgroundColor).opacity(0.6)
                        
                        VStack(spacing: 12) {
                            Image(systemName: "plus.app.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.secondary)
                            
                            Text("Premium Feature")
                                .font(.headline)
                            
                            Text("Upgrade to VisorPro Premium to unlock these settings.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(30)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    }
                )
        }
    }
}

extension View {
    func premiumLocked(if notPremium: Bool) -> some View {
        self.modifier(PremiumLockModifier(isPremium: !notPremium))
    }
}

struct LicenseInfoRow: View {
    let title: String
    let value: String
    let icon: String
    var valueColor: Color = .primary
    

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(valueColor)
                
                Text(value)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(valueColor)
            }
        }
    }
}
