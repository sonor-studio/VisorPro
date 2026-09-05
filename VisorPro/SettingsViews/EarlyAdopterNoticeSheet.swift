import SwiftUI
import WebKit

struct EarlyAdopterNoticeSheet: View {
    @Binding var isPresented: Bool
    @Binding var hasSeenNotice: Bool
    @Binding var savedLicenseKey: String
    
    @State private var countdown = 5
    @State private var canProceed = false
    @State private var showingCheckout = false
    @State private var showingActivation = false
    @StateObject private var licenseManager = PolarLicenseManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 42))
                .foregroundColor(.green)
                .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 4)
                .padding(.top, 8)
            
            VStack(spacing: 6) {
                Text("Early Adopter License")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Your lifetime access is ready.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "gift.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 18))
                        .frame(width: 24)
                    
                    Text("As an early supporter, you can unlock lifetime access to all features for free by using the code below at checkout.")
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "key.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 18))
                        .frame(width: 24)
                    
                    Text("We've launched a new licensing system. Claim your personal key to unlock all trackers permanently.")
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            
            VStack(spacing: 8) {
                Text("100% DISCOUNT CODE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1)

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("EARLY", forType: .string)
                }) {
                    HStack(spacing: 12) {
                        Text("EARLY")
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .tracking(4)
                        
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 14))
                            .opacity(0.6)
                    }
                    .foregroundColor(.primary)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 32)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .help("Click to copy promo code")
            }
            .padding(.bottom, 4)
            
            Divider()
                .opacity(0.5)
            
            VStack(spacing: 12) {
                Button(action: {
                    
                    showingCheckout = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                        if canProceed {
                            Text("Go to Checkout")
                                .fontWeight(.semibold)
                        } else {
                            Text("Go to Checkout (\(countdown)s)")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(Color(NSColor.windowBackgroundColor))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.primary)
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!canProceed)
                .opacity(canProceed ? 1.0 : 0.6)
                
                HStack(spacing: 16) {
                    Button(action: {
                        showingActivation = true
                    }) {
                        Text("I already have a key")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    if canProceed {
                        Button(action: {
                            hasSeenNotice = true
                            isPresented = false
                        }) {
                            Text("Don't remind me")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            isPresented = false
                        }) {
                            Text("Remind me later")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(26)
        .frame(width: 440)
        .onAppear {
            Task {
                while countdown > 0 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await MainActor.run {
                        countdown -= 1
                        if countdown == 0 {
                            canProceed = true
                        }
                    }
                }
            }
        }
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
                    Button(action: { 
                        showingCheckout = false
                        if !savedLicenseKey.isEmpty {
                            isPresented = false
                        }
                    }) {
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
        .onChange(of: savedLicenseKey) { oldValue, newValue in
            if !newValue.isEmpty {
                hasSeenNotice = true
                isPresented = false
            }
        }
    }
}
