import SwiftUI
import WebKit

struct PremiumLockedView: View {
    @AppStorage("PremiumLicenseKey") private var savedLicenseKey = ""
    @State private var showingCheckout = false
    @State private var showingActivation = false
    @StateObject private var licenseManager = PolarLicenseManager()
    
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 34))
                .foregroundColor(.green)
                .shadow(color: Color.green.opacity(0.25), radius: 6, x: 0, y: 3)
                .padding(.bottom, 2)
            
            Text("Premium Tracker")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
                        Text("This tracker is included with VisorPro Premium. As an early supporter, you can unlock it for free by using promo code EARLY at checkout.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 380)

            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("EARLY", forType: .string)
            }) {
                HStack(spacing: 6) {
                    Text("CODE: EARLY")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 10))
                }
                .foregroundColor(.primary)
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .background(Color.primary.opacity(0.06))
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Copy promo code")
            
            HStack(spacing: 12) {
                Button(action: {
                    showingCheckout = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                        Text("Go to Checkout")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(Color(NSColor.windowBackgroundColor))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.primary)
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    showingActivation = true
                }) {
                    Text("Enter Key")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 6)
            
            Button(action: {
                NotificationCenter.default.post(name: NSNotification.Name("OpenPremiumSettings"), object: nil)
            }) {
                Text("View all Premium features")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .underline()
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 4)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showingCheckout) {
            VStack(spacing: 0) {
                HStack {
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
