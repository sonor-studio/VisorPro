import SwiftUI
import WebKit
import AppKit

struct PremiumSettingsView: View {
    @State private var showingCheckout = false
    @State private var showingActivation = false
    @State private var isKeyCopied = false
    @StateObject private var licenseManager = PolarLicenseManager()
    
    @AppStorage("PremiumLicenseKey") private var savedLicenseKey = ""
    @AppStorage("licenseActivationDate") private var activationDate = ""
    @AppStorage("licenseActivationId") private var activationId = ""


    private var buyButton: some View {
        Button(action: { showingCheckout = true }) {
            HStack(spacing: 8) {
                Image(systemName: "cart.fill")
                Text("Buy Premium")
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
                            .font(.system(size: 18, weight: .medium))
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
                                    
                                    Button(action: {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(savedLicenseKey, forType: .string)
                                        withAnimation {
                                            isKeyCopied = true
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            withAnimation {
                                                isKeyCopied = false
                                            }
                                        }
                                    }) {
                                        Image(systemName: isKeyCopied ? "checkmark" : "doc.on.doc")
                                            .font(.system(size: 12))
                                            .foregroundColor(isKeyCopied ? .green : .secondary)
                                            .padding(6)
                                            .background(Color.primary.opacity(0.05))
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .help(isKeyCopied ? "Copied!" : "Copy license key")
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
                                    Task {
                                        if !activationId.isEmpty {
                                            _ = await licenseManager.deactivateKey(key: savedLicenseKey, activationId: activationId)
                                        }
                                        await MainActor.run {
                                            savedLicenseKey = ""
                                            activationId = ""
                                            activationDate = ""
                                        }
                                    }
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
                            title: "Storage Tracker",
                            description: "Monitor your disk space and get alerts when storage is low.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(Color.purple.opacity(0.05))
                                UniversalOverlayView(
                                    isPreview: true,
                                    isExpanded: .constant(false),
                                    showProgressBar: true,
                                    progress: 0.85,
                                    barColor: .purple,
                                    customWidth: 170,
                                    customCornerRadius: 28,
                                    forceGlow: false,
                                    isExpandable: false,
                                    baseContent: {
                                        HStack(alignment: .center, spacing: 14) {
                                            Image(systemName: "internaldrive.fill")
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(.primary)
                                                .frame(width: 26, height: 24)
                                            
                                            VStack(alignment: .leading, spacing: 6) {
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Color.primary.opacity(0.6))
                                                    .frame(width: 55, height: 7)
                                                
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Color.secondary.opacity(0.4))
                                                    .frame(width: 40, height: 5)
                                            }
                                            Spacer(minLength: 8)
                                        }
                                        .padding(.horizontal, 20)
                                    },
                                    expandedContent: { EmptyView() }
                                )
                                .scaleEffect(0.9)
                            }
                        )
                        
                        WidgetPreviewCard(
                            title: "Bluetooth Tracker",
                            description: "Monitor connectivity and battery of AirPods and other devices.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(Color.indigo.opacity(0.05))
                                UniversalOverlayView(
                                    isPreview: true,
                                    isExpanded: .constant(true),
                                    showProgressBar: true, progress: 0.8,
                                    barColor: .indigo,
                                    customWidth: 160,
                                    customCornerRadius: 24,
                                    forceGlow: false,
                                    isExpandable: true,
                                    baseContent: {
                                        HStack(alignment: .center, spacing: 14) {
                                            Image(systemName: "airpodsmax")
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(.primary)
                                                .frame(width: 26, height: 24)
                                            
                                            VStack(alignment: .leading, spacing: 6) {
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Color.primary.opacity(0.6))
                                                    .frame(width: 65, height: 7)
                                                
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Color.secondary.opacity(0.4))
                                                    .frame(width: 40, height: 5)
                                            }
                                            
                                            Spacer(minLength: 8)
                                        }
                                        .padding(.horizontal, 20)
                                    },
                                    expandedContent: {
                                        HStack(alignment: .bottom, spacing: 20) {
                                            VStack(spacing: 8) {
                                                Image(systemName: "airpodpro.left").font(.system(size: 18, weight: .medium)).foregroundColor(.secondary)
                                                RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.6)).frame(width: 14, height: 4)
                                            }
                                            VStack(spacing: 8) {
                                                Image(systemName: "airpodspro.chargingcase.wireless.fill").font(.system(size: 18)).foregroundColor(.secondary)
                                                RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.6)).frame(width: 14, height: 4)
                                            }
                                            VStack(spacing: 8) {
                                                Image(systemName: "airpodpro.right").font(.system(size: 18, weight: .medium)).foregroundColor(.secondary)
                                                RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.6)).frame(width: 14, height: 4)
                                            }
                                        }
                                        .padding(.horizontal, 20).padding(.bottom, 14).padding(.top, 4)
                                    }
                                )
                                .scaleEffect(0.9)
                            }
                        )
                        
                        WidgetPreviewCard(
                            title: "Privacy Tracker",
                            description: "Know instantly when your camera, mic, or location is accessed.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.05))
                                UniversalOverlayView(
                                    isPreview: true,
                                    isExpanded: .constant(false),
                                    showProgressBar: true, progress: 1.0,
                                    barColor: .green,
                                    customWidth: 170,
                                    customCornerRadius: 28,
                                    forceGlow: false,
                                    isExpandable: false,
                                    baseContent: {
                                        HStack(alignment: .center, spacing: 16) {
                                            Image(systemName: "video.fill").font(.system(size: 18, weight: .medium)).foregroundColor(.primary)
                                            Image(systemName: "mic.fill").font(.system(size: 18, weight: .medium)).foregroundColor(.primary)
                                            Image(systemName: "location.fill").font(.system(size: 18, weight: .medium)).foregroundColor(.primary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 16)
                                    },
                                    expandedContent: { EmptyView() }
                                )
                                .scaleEffect(0.9)
                            }
                        )
                        
                        WidgetPreviewCard(
                            title: "System Tracker",
                            description: "Monitor your real-time memory usage and performance stats.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.05))
                                UniversalOverlayView(
                                    isPreview: true,
                                    isExpanded: .constant(false),
                                    showProgressBar: true, progress: 0.45,
                                    barColor: .orange,
                                    customWidth: 170,
                                    customCornerRadius: 28,
                                    forceGlow: false,
                                    isExpandable: false,
                                    baseContent: {
                                        HStack(alignment: .center, spacing: 14) {
                                            Image(systemName: "cpu")
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(.primary)
                                                .frame(width: 26, height: 24)
                                            
                                            VStack(alignment: .leading, spacing: 6) {
                                                // CPU bar
                                                GeometryReader { geo in
                                                    ZStack(alignment: .leading) {
                                                        RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.2))
                                                        RoundedRectangle(cornerRadius: 2).fill(Color.orange.opacity(0.8)).frame(width: geo.size.width * 0.65)
                                                    }
                                                }.frame(height: 5)
                                                
                                                // RAM bar
                                                GeometryReader { geo in
                                                    ZStack(alignment: .leading) {
                                                        RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.2))
                                                        RoundedRectangle(cornerRadius: 2).fill(Color.orange.opacity(0.5)).frame(width: geo.size.width * 0.4)
                                                    }
                                                }.frame(height: 5)
                                            }
                                            .frame(width: 60)
                                            
                                            Spacer(minLength: 8)
                                        }
                                        .padding(.horizontal, 20)
                                    },
                                    expandedContent: { EmptyView() }
                                )
                                .scaleEffect(0.9)
                            }
                        )
                        
                        WidgetPreviewCard(
                            title: "Wi-Fi Tracker",
                            description: "Monitor your network connection status and speed.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(Color.cyan.opacity(0.05))
                                UniversalOverlayView(
                                    isPreview: true,
                                    isExpanded: .constant(false),
                                    showProgressBar: true, progress: 1.0,
                                    barColor: .cyan,
                                    customWidth: 170,
                                    customCornerRadius: 28,
                                    forceGlow: false,
                                    isExpandable: false,
                                    baseContent: {
                                        HStack(alignment: .center, spacing: 14) {
                                            Image(systemName: "wifi")
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(.primary)
                                                .frame(width: 26, height: 24)
                                            
                                            VStack(alignment: .leading, spacing: 6) {
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Color.primary.opacity(0.6))
                                                    .frame(width: 62, height: 7)
                                                
                                                HStack(spacing: 8) {
                                                    HStack(spacing: 3) { Image(systemName: "arrow.down").font(.system(size: 9, weight: .bold)).foregroundColor(.green); RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.4)).frame(width: 15, height: 4) }
                                                    HStack(spacing: 3) { Image(systemName: "arrow.up").font(.system(size: 9, weight: .bold)).foregroundColor(.blue); RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.4)).frame(width: 15, height: 4) }
                                                }
                                            }
                                            Spacer(minLength: 8)
                                        }
                                        .padding(.horizontal, 20)
                                    },
                                    expandedContent: { EmptyView() }
                                )
                                .scaleEffect(0.9)
                            }
                        )
                        

                        WidgetPreviewCard(
                            title: "Display Tracker",
                            description: "Stay informed about your external displays and monitor connections.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(Color.teal.opacity(0.05))
                                UniversalOverlayView(
                                    isPreview: true,
                                    isExpanded: .constant(false),
                                    showProgressBar: true, progress: 1.0,
                                    barColor: .teal,
                                    customWidth: 170,
                                    customCornerRadius: 28,
                                    forceGlow: false,
                                    isExpandable: false,
                                    baseContent: {
                                        HStack(alignment: .center, spacing: 14) {
                                            Image(systemName: "display")
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(.primary)
                                                .frame(width: 26, height: 24)
                                            
                                            VStack(alignment: .leading, spacing: 6) {
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Color.primary.opacity(0.6))
                                                    .frame(width: 65, height: 7)
                                                
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Color.secondary.opacity(0.4))
                                                    .frame(width: 40, height: 5)
                                            }
                                            
                                            Spacer(minLength: 8)
                                        }
                                        .padding(.horizontal, 20)
                                    },
                                    expandedContent: { EmptyView() }
                                )
                                .scaleEffect(0.9)
                            }
                        )

                        WidgetPreviewCard(
                            title: "Trash Tracker",
                            description: "Monitor your trash bin size and empty it directly from the overlay.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.05))
                                
                                UniversalOverlayView(
                                    isPreview: true,
                                    isExpanded: .constant(false),
                                    showProgressBar: true, progress: 1.0,
                                    barColor: .red,
                                    customWidth: 180,
                                    customCornerRadius: 28,
                                    forceGlow: false,
                                    isExpandable: false,
                                    baseContent: {
                                        HStack(alignment: .center, spacing: 14) {
                                            Image(systemName: "trash.fill")
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(.primary)
                                                .frame(width: 26, height: 24)
                                            
                                            VStack(alignment: .leading, spacing: 6) {
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Color.primary.opacity(0.6))
                                                    .frame(width: 45, height: 7)
                                                
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Color.secondary.opacity(0.4))
                                                    .frame(width: 30, height: 5)
                                            }
                                            
                                            Spacer(minLength: 4)
                                            
                                            ZStack {
                                                Circle()
                                                    .fill(Color.primary.opacity(0.1))
                                                    .frame(width: 30, height: 30)
                                                Image(systemName: "arrow.counterclockwise")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.primary)
                                            }
                                        }
                                        .padding(.leading, 20)
                                        .padding(.trailing, 13)
                                    },
                                    expandedContent: { EmptyView() }
                                )
                                .scaleEffect(0.9)
                            }
                        )
                        
                        WidgetPreviewCard(
                            title: "Focus Tracker",
                            description: "Stay in the zone with alerts when your Focus modes change.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(Color.indigo.opacity(0.05))
                                UniversalOverlayView(
                                    isPreview: true,
                                    isExpanded: .constant(false),
                                    showProgressBar: true, progress: 1.0,
                                    barColor: .indigo,
                                    customWidth: 170,
                                    customCornerRadius: 28,
                                    forceGlow: false,
                                    isExpandable: false,
                                    baseContent: {
                                        HStack(alignment: .center, spacing: 14) {
                                            Image(systemName: "moon.fill")
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(.primary)
                                                .frame(width: 26, height: 24)
                                            
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color.primary.opacity(0.6))
                                                .frame(width: 75, height: 7)
                                            
                                            Spacer(minLength: 8)
                                        }
                                        .padding(.horizontal, 20)
                                    },
                                    expandedContent: { EmptyView() }
                                )
                                .scaleEffect(0.9)
                            }
                        )
                        
                        WidgetPreviewCard(
                                                        title: "More Overlays",
                            description: "Display up to 5 active tracker notifications on your screen simultaneously.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(Color.pink.opacity(0.05))
                                
                                VStack(spacing: -18) {
                                    UniversalOverlayView(isPreview: true, isExpanded: .constant(false), showProgressBar: true, progress: 1.0, barColor: .pink, customWidth: 140, customHeight: 40, customCornerRadius: 20, forceGlow: false, isExpandable: false, baseContent: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "bell.fill").foregroundColor(.primary).font(.system(size: 18, weight: .medium))
                                            RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.6)).frame(width: 45, height: 5)
                                            Spacer()
                                        }.padding(.horizontal, 16)
                                    }, expandedContent: { EmptyView() })
                                    .scaleEffect(0.85).opacity(0.5).zIndex(1)
                                    
                                    UniversalOverlayView(isPreview: true, isExpanded: .constant(false), showProgressBar: true, progress: 1.0, barColor: .teal, customWidth: 140, customHeight: 40, customCornerRadius: 20, forceGlow: false, isExpandable: false, baseContent: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "message.fill").foregroundColor(.primary).font(.system(size: 18, weight: .medium))
                                            RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.6)).frame(width: 55, height: 5)
                                            Spacer()
                                        }.padding(.horizontal, 16)
                                    }, expandedContent: { EmptyView() })
                                    .scaleEffect(0.95).opacity(0.8).zIndex(2)
                                    
                                    UniversalOverlayView(isPreview: true, isExpanded: .constant(false), showProgressBar: true, progress: 1.0, barColor: .indigo, customWidth: 140, customHeight: 40, customCornerRadius: 20, forceGlow: false, isExpandable: false, baseContent: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "square.3.layers.3d").foregroundColor(.primary).font(.system(size: 18, weight: .medium))
                                            RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.6)).frame(width: 40, height: 5)
                                            Spacer()
                                        }.padding(.horizontal, 16)
                                    }, expandedContent: { EmptyView() })
                                    .zIndex(3)
                                }
                                .offset(y: 4)
                            }
                        )
                        WidgetPreviewCard(
                            title: "Overlay Colors",
                            description: "Customize the color scheme of your overlays with presets or choose your own style.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.orange.opacity(0.05))
                                
                                HStack(spacing: -8) {
                                    Circle().fill(Color.red.opacity(0.8)).frame(width: 32, height: 32)
                                        .overlay(Circle().stroke(Color(NSColor.windowBackgroundColor), lineWidth: 2))
                                    Circle().fill(Color.orange.opacity(0.8)).frame(width: 32, height: 32)
                                        .overlay(Circle().stroke(Color(NSColor.windowBackgroundColor), lineWidth: 2))
                                    Circle().fill(Color.blue.opacity(0.8)).frame(width: 32, height: 32)
                                        .overlay(Circle().stroke(Color(NSColor.windowBackgroundColor), lineWidth: 2))
                                    Circle().fill(Color.purple.opacity(0.8)).frame(width: 32, height: 32)
                                        .overlay(Circle().stroke(Color(NSColor.windowBackgroundColor), lineWidth: 2))
                                }
                                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                            }
                        )
                        
                        WidgetPreviewCard(
                            title: "Inner Glow Effect",
                            description: "Elevate your overlays with the new Inner Glow aesthetic. This subtle lighting effect adds beautiful depth and polish to the glass material.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(Color.purple.opacity(0.05))
                                
                                UniversalOverlayView(
                                    isPreview: true,
                                    isExpanded: .constant(false),
                                    showProgressBar: true,
                                    progress: 0.5,
                                    barColor: .purple,
                                    customWidth: 170,
                                    customCornerRadius: 28,
                                    forceGlow: true,
                                    customGlowOpacity: 0.15,
                                    isExpandable: false,
                                    baseContent: {
                                        HStack(alignment: .center, spacing: 14) {
                                            Image(systemName: "sun.max.fill")
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(.primary)
                                                .frame(width: 26, height: 24)
                                            
                                            VStack(alignment: .leading, spacing: 6) {
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Color.secondary.opacity(0.4))
                                                    .frame(width: 40, height: 6)
                                                
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Color.primary.opacity(0.5))
                                                    .frame(width: 65, height: 8)
                                            }
                                            Spacer(minLength: 8)
                                        }
                                        .padding(.horizontal, 20)
                                    },
                                    expandedContent: {
                                        EmptyView()
                                    }
                                )
                                .scaleEffect(0.85)
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
                
                Spacer(minLength: 20)
            }
            .padding(24)
        }
        // Removed rigid white background so the view inherits transparency from SettingsView
        .background(Color.clear)
        .sheet(isPresented: $showingCheckout) {
            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        NSWorkspace.shared.open(URL(string: "https://buy.polar.sh/polar_cl_PInjogqryIOSYRz17wX36JqBy15auEMjHYREM1Gspct")!)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "safari")
                            Text("Open in Browser (For Apple Pay)")
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

// MARK: - Activation Popup View

struct ActivationPopupView: View {
    @Binding var isPresented: Bool
    @ObservedObject var licenseManager: PolarLicenseManager
    @Binding var savedLicenseKey: String
    
    @AppStorage("licenseActivationDate") private var activationDate = ""
    @AppStorage("licenseActivationId") private var activationId = ""
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
                        if let newActivationId = await licenseManager.activateKey(key: cleanKey) {
                            savedLicenseKey = cleanKey
                            activationId = newActivationId
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
