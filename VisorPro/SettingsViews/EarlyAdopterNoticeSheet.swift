import SwiftUI
import WebKit
import Combine

struct EarlyAdopterNoticeSheet: View {
    @Binding var isPresented: Bool
    @Binding var hasSeenNotice: Bool
    @Binding var savedLicenseKey: String
    
    @State private var countdown = 3
    @State private var canProceed = false
    @State private var showingCheckout = false
    @State private var showingActivation = false
    @StateObject private var licenseManager = PolarLicenseManager()
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
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
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Thank you for supporting VisorPro early. As promised, your lifetime access to all features is completely free of charge.")
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .lineSpacing(2)
                
                Text("We recently introduced an official licensing system. You can generate your personal license key below to unlock all trackers permanently.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 8)
            
            Divider()
                .opacity(0.5)
            
            VStack(spacing: 12) {
                Button(action: {
                    hasSeenNotice = true
                    showingCheckout = true
                }) {
                    HStack(spacing: 8) {
                        if canProceed {
                            Text("Get Free License")
                                .fontWeight(.semibold)
                        } else {
                            Text("Get Free License (\(countdown)s)")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
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
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Remind me later")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(26)
        .frame(width: 440)
        .onReceive(timer) { _ in
            if countdown > 1 {
                countdown -= 1
            } else {
                canProceed = true
            }
        }
        .sheet(isPresented: $showingCheckout) {
            VStack(spacing: 0) {
                HStack {
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
        .onChange(of: savedLicenseKey) { newValue in
            if !newValue.isEmpty {
                hasSeenNotice = true
                isPresented = false
            }
        }
    }
}
