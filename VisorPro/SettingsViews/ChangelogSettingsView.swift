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
                
                // Version 1.2.0 Area
                VStack(alignment: .leading, spacing: 16) {
                    Text("VisorPro 1.2.0")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Massive update for AirPods & Accessories, custom battery alerts, Date & Trash overlays, and a cleaner system UI.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                    
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 24), GridItem(.flexible(), spacing: 24)], spacing: 32) {
                        
                        ChangelogCard(
                            icon: "airpodspro",
                            title: "Apple AirPods",
                            description: "Unprecedented support for AirPods. Detailed component-level battery alerts, case open overlays, and Listening Mode controls.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.05))
                                
                                ZStack {
                                    // Background tilted block
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.blue.opacity(0.15))
                                        .frame(width: 80, height: 60)
                                        .rotationEffect(.degrees(10))
                                        .offset(x: -12, y: -5)
                                        
                                    // Main card
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                        .frame(width: 80, height: 60)
                                        .rotationEffect(.degrees(-5))
                                        .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
                                        .overlay(
                                            Image(systemName: "airpodspro")
                                                .font(.system(size: 28))
                                                .foregroundColor(.blue)
                                                .rotationEffect(.degrees(-5))
                                        )
                                }
                            }
                        )
                        
                        ChangelogCard(
                            icon: "magicmouse.fill",
                            title: "Bluetooth Accessories",
                            description: "Devices that report battery life now get their own dedicated settings, distinct from regular Bluetooth or peripheral connections.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(Color.teal.opacity(0.05))
                                
                                VStack(spacing: 0) {
                                    // Row 1: Mouse
                                    HStack(spacing: 12) {
                                        Image(systemName: "magicmouse.fill").foregroundColor(.teal).font(.system(size: 16)).frame(width: 20)
                                        Text("Magic Mouse").font(.system(size: 12, weight: .semibold))
                                        Spacer()
                                        Image(systemName: "battery.75").foregroundColor(.secondary).font(.system(size: 14))
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 10)
                                    
                                    Divider().padding(.leading, 40)
                                    
                                    // Row 2: Keyboard
                                    HStack(spacing: 12) {
                                        Image(systemName: "keyboard.fill").foregroundColor(.teal).font(.system(size: 16)).frame(width: 20)
                                        Text("Magic Keyboard").font(.system(size: 12, weight: .semibold))
                                        Spacer()
                                        Image(systemName: "battery.25").foregroundColor(.secondary).font(.system(size: 14))
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 10)
                                }
                                .frame(width: 190)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(10)
                                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                            }
                        )
                        
                        ChangelogCard(
                            icon: "battery.100.bolt",
                            title: "Custom Battery Alerts",
                            description: "Set your own percentage thresholds for low or full battery alerts on your Mac, accessories, or even specific AirPods components.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.05))
                                VStack(spacing: 12) {
                                    // Slider mock
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.2)).frame(width: 130, height: 8)
                                        RoundedRectangle(cornerRadius: 4).fill(Color.green.opacity(0.6)).frame(width: 90, height: 8)
                                        Circle().fill(Color.white).frame(width: 18, height: 18).shadow(color: .black.opacity(0.2), radius: 2).offset(x: 81)
                                    }
                                    HStack {
                                        Image(systemName: "battery.75").font(.system(size: 16)).foregroundColor(.green)
                                        Text("70%").font(.system(size: 16, weight: .bold)).foregroundColor(.green)
                                    }
                                }
                            }
                        )
                        
                        ChangelogCard(
                            icon: "eye.slash.fill",
                            title: "System Overlays Hidden",
                            description: "No more overlapping! We've successfully engineered a way to hide all duplicating native macOS overlays, keeping your screen clean.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(Color.purple.opacity(0.05))
                                
                                VStack(spacing: 0) {
                                    // Screen
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.secondary.opacity(0.4), lineWidth: 2)
                                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
                                            .frame(width: 120, height: 75)
                                        
                                        // macOS Native Mock (inside the screen, no slash)
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.15)).frame(width: 40, height: 40)
                                            VStack(spacing: 4) {
                                                Image(systemName: "speaker.wave.3.fill").font(.system(size: 14)).foregroundColor(.secondary.opacity(0.5))
                                                HStack(spacing: 2) {
                                                    ForEach(0..<6, id: \.self) { _ in
                                                        RoundedRectangle(cornerRadius: 1).fill(Color.secondary.opacity(0.4)).frame(width: 3, height: 3)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Stand
                                    RoundedRectangle(cornerRadius: 1).fill(Color.secondary.opacity(0.4)).frame(width: 4, height: 10)
                                    // Base
                                    RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.4)).frame(width: 30, height: 3)
                                }
                            }
                        )
                        
                        ChangelogCard(
                            icon: "sparkles.square.filled.on.square",
                            title: "New Overlays",
                            description: "Introducing beautiful new overlays for Date changes, Trash capacity & deletion events, and precise CPU Temperature monitoring.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.05))
                                
                                ZStack {
                                    // Back (CPU)
                                    HStack(spacing: 12) {
                                        Image(systemName: "thermometer.medium").foregroundColor(.orange).font(.system(size: 14))
                                        Text("CPU at 48°C").font(.system(size: 11, weight: .bold))
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .frame(width: 140)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)
                                    .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                                    .offset(x: -12, y: -28)
                                    .rotationEffect(.degrees(-3))
                                    
                                    // Middle (Trash)
                                    HStack(spacing: 12) {
                                        Image(systemName: "trash.fill").foregroundColor(.secondary).font(.system(size: 14))
                                        Text("Trash Emptied").font(.system(size: 11, weight: .bold))
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .frame(width: 140)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)
                                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                                    
                                    // Front (Date)
                                    HStack(spacing: 12) {
                                        Image(systemName: "calendar.badge.clock").foregroundColor(.red).font(.system(size: 14))
                                        Text("Wed, 24 Sep").font(.system(size: 11, weight: .bold))
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .frame(width: 140)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)
                                    .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
                                    .offset(x: 12, y: 28)
                                    .rotationEffect(.degrees(3))
                                }
                            }
                        )
                        
                        ChangelogCard(
                            icon: "hand.tap.fill",
                            title: "Quick Action Buttons",
                            description: "Perform immediate actions directly from overlays. Instantly restore deleted files, empty the trash, or revert keyboard language without expanding.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.05))
                                
                                UniversalOverlayView(
                                    isPreview: true,
                                    isExpanded: .constant(false),
                                    showProgressBar: false,
                                    barColor: .indigo,
                                    customWidth: 200,
                                    isExpandable: false,
                                    baseContent: {
                                        HStack(alignment: .center, spacing: 14) {
                                            Image(systemName: "moon.fill")
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(.indigo)
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
                                            
                                            // Quick Action Button
                                            ZStack {
                                                Circle().fill(Color.secondary.opacity(0.15)).frame(width: 32, height: 32)
                                                Image(systemName: "arrow.uturn.backward").foregroundColor(.secondary).font(.system(size: 14, weight: .bold))
                                            }
                                        }
                                        .padding(.leading, 20)
                                        .padding(.trailing, 18)
                                    },
                                    expandedContent: {
                                        EmptyView()
                                    }
                                )
                                .scaleEffect(0.90)
                                .mask(
                                    LinearGradient(gradient: Gradient(stops: [
                                        .init(color: .clear, location: 0.0),
                                        .init(color: .clear, location: 0.35),
                                        .init(color: .black, location: 0.7),
                                        .init(color: .black, location: 1.0)
                                    ]), startPoint: .leading, endPoint: .trailing)
                                )
                                .offset(x: -40)
                            }
                        )
                        
                        ChangelogCard(
                            icon: "wifi",
                            title: "Wi-Fi Speedtest",
                            description: "The Wi-Fi overlay has been upgraded. You can now run a built-in speedtest directly from the expanded view to check your connection.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.05))
                                
                                VStack(spacing: 8) {
                                    // Header
                                    HStack(alignment: .lastTextBaseline) {
                                        Text("Speed Test Complete")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(.blue)
                                    }
                                    .padding(.horizontal, 4)
                                    
                                    // Stats box
                                    HStack(spacing: 4) {
                                        // Download
                                        VStack(alignment: .center, spacing: 2) {
                                            Text("Download").font(.system(size: 8, weight: .medium, design: .rounded)).foregroundColor(.secondary)
                                            Text("350.5").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(.primary)
                                            Text("Mbps").font(.system(size: 7, weight: .medium, design: .rounded)).foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        
                                        Divider().frame(height: 16)
                                        
                                        // Upload
                                        VStack(alignment: .center, spacing: 2) {
                                            Text("Upload").font(.system(size: 8, weight: .medium, design: .rounded)).foregroundColor(.secondary)
                                            Text("120.2").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(.primary)
                                            Text("Mbps").font(.system(size: 7, weight: .medium, design: .rounded)).foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        
                                        Divider().frame(height: 16)
                                        
                                        // Ping
                                        VStack(alignment: .center, spacing: 2) {
                                            Text("Ping").font(.system(size: 8, weight: .medium, design: .rounded)).foregroundColor(.secondary)
                                            Text("12").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(.primary)
                                            Text("ms").font(.system(size: 7, weight: .medium, design: .rounded)).foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 4)
                                    .background(Color.primary.opacity(0.05))
                                    .cornerRadius(6)
                                }
                                .padding(12)
                                .frame(width: 220)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(10)
                                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                            }
                        )
                        
                        ChangelogCard(
                            icon: "arrow.uturn.backward",
                            title: "Show Last Overlay",
                            description: "Quickly recall your most recent overlay. This new action is available directly from the Menu Bar or can be triggered via a custom keyboard shortcut.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(Color.indigo.opacity(0.05))
                                
                                // Background (previous) overlay, faded out
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(NSColor.controlBackgroundColor))
                                    .frame(width: 80, height: 50)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.indigo.opacity(0.2), lineWidth: 1)
                                    )
                                    .opacity(0.5)
                                    .scaleEffect(0.85)
                                    .offset(y: -15)
                                    
                                // Foreground (recalled) overlay
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(NSColor.controlBackgroundColor))
                                    .frame(width: 90, height: 60)
                                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                                    .overlay(
                                        VStack(spacing: 8) {
                                            Image(systemName: "arrow.uturn.backward")
                                                .font(.system(size: 22, weight: .semibold))
                                                .foregroundColor(.indigo)
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(Color.indigo.opacity(0.4))
                                                .frame(width: 30, height: 4)
                                        }
                                    )
                                    .offset(y: 5)
                            }
                        )
                        
                        ChangelogCard(
                            icon: "bolt.fill",
                            title: "Performance & Fixes",
                            description: "Implemented massive visual refinements, UI logic and performance optimizations, and various bug and crash fixes for a smoother experience.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(Color.yellow.opacity(0.05))
                                
                                ZStack(alignment: .bottomTrailing) {
                                    // Window mock
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                        .frame(width: 100, height: 60)
                                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                                        .overlay(
                                            VStack(alignment: .leading, spacing: 6) {
                                                RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.2)).frame(width: 60, height: 4)
                                                RoundedRectangle(cornerRadius: 2).fill(Color.yellow.opacity(0.4)).frame(width: 45, height: 4)
                                                RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.2)).frame(width: 35, height: 4)
                                            }.padding(12), alignment: .topLeading
                                        )
                                        
                                    // Lightning badge on the corner
                                    ZStack {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 22, height: 22)
                                            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                                        
                                        Image(systemName: "bolt.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.yellow)
                                    }
                                    .offset(x: 8, y: 8)
                                }
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                    .padding(.vertical, 32)
                
                // Version 1.1.0 Area
                VStack(alignment: .leading, spacing: 16) {
                    Text("VisorPro 1.1.0")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("New Focus overlay, Free & Premium tiers, Polar license manager, and stability fixes.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                    
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 24), GridItem(.flexible(), spacing: 24)], spacing: 32) {
                        
                        ChangelogCard(
                            icon: "signature",
                            title: "Signature & Keychain",
                            description: "Fixed a critical bug related to app signing and the keychain, significantly improving overall app stability and reliability.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.05))
                                
                                // Centered Window Mock
                                ZStack(alignment: .bottomTrailing) {
                                    VStack(spacing: 0) {
                                        HStack(spacing: 4) {
                                            Circle().fill(Color.red.opacity(0.5)).frame(width: 6, height: 6)
                                            Circle().fill(Color.yellow.opacity(0.5)).frame(width: 6, height: 6)
                                            Circle().fill(Color.green.opacity(0.5)).frame(width: 6, height: 6)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .background(Color.secondary.opacity(0.1))
                                        
                                        VStack(alignment: .leading, spacing: 6) {
                                            RoundedRectangle(cornerRadius: 2).fill(Color.blue.opacity(0.3)).frame(width: 80, height: 4)
                                            RoundedRectangle(cornerRadius: 2).fill(Color.blue.opacity(0.2)).frame(width: 50, height: 4)
                                            Spacer()
                                        }
                                        .padding(10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .frame(width: 120, height: 70)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)
                                    .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                                    
                                    // Shield exactly on the bottom-right corner of the window
                                    Image(systemName: "checkmark.shield.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.blue)
                                        .background(Circle().fill(Color(NSColor.windowBackgroundColor)).frame(width: 20, height: 20))
                                        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                                        .offset(x: 8, y: 8)
                                }
                            }
                        )
                        
                        ChangelogCard(
                            icon: "moon.stars.fill",
                            title: "The Focus Overlay",
                            description: "A completely new addition! Isolate your workflow, dim distractions, and stay perfectly in the zone with the new Focus mode.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.indigo.opacity(0.05))
                                
                                UniversalOverlayView(
                                    isPreview: true,
                                    isExpanded: .constant(false),
                                    showProgressBar: false,
                                    barColor: .indigo,
                                    customWidth: 170,
                                    isExpandable: false,
                                    baseContent: {
                                        HStack(alignment: .center, spacing: 14) {
                                            Image(systemName: "moon.fill")
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(.indigo)
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
                                .scaleEffect(0.95)
                            }
                        )
                        
                        ChangelogCard(
                            icon: "square.split.2x1",
                            title: "Free vs Premium",
                            description: "Features are now divided into Free and Premium tiers. Good news: early adopters can claim a lifetime Premium license for free!",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green.opacity(0.05))
                                
                                // Abstract List Layout
                                VStack(spacing: 10) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "cube.box")
                                            .foregroundColor(.secondary.opacity(0.6))
                                            .font(.system(size: 16))
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.secondary.opacity(0.3))
                                            .frame(width: 60, height: 6)
                                        Spacer()
                                    }
                                    
                                    Divider().frame(width: 110)
                                    
                                    HStack(spacing: 12) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 16))
                                        VStack(alignment: .leading, spacing: 5) {
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color.green.opacity(0.5))
                                                .frame(width: 80, height: 6)
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color.green.opacity(0.3))
                                                .frame(width: 40, height: 4)
                                        }
                                        Spacer()
                                    }
                                }
                                .padding(.horizontal, 30)
                            }
                        )
                        
                        ChangelogCard(
                            icon: "key.fill",
                            title: "Polar License Manager",
                            description: "We've fully replaced Keychain with a robust license manager via the Polar platform. Claim your free Early Adopter key effortlessly.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.teal.opacity(0.05))
                                
                                // Overlapping abstract cards
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.teal.opacity(0.2))
                                        .frame(width: 90, height: 60)
                                        .rotationEffect(.degrees(-8))
                                        .offset(x: -10, y: 5)
                                    
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                        .frame(width: 90, height: 60)
                                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10).stroke(Color.teal.opacity(0.3), lineWidth: 1)
                                        )
                                    
                                    VStack(spacing: 8) {
                                        Image(systemName: "key.fill")
                                            .foregroundColor(.teal)
                                            .font(.system(size: 18))
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.teal.opacity(0.5))
                                            .frame(width: 40, height: 4)
                                    }
                                }
                            }
                        )
                        
                        ChangelogCard(
                            icon: "xmark.circle",
                            title: "Smart Close Buttons",
                            description: "You can now quickly close any active overlay. Just hover your cursor over it and a close button will intuitively appear.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.pink.opacity(0.05))
                                
                                ZStack(alignment: .topLeading) {
                                    // Abstract Overlay Mock
                                    VStack(alignment: .leading, spacing: 6) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.pink.opacity(0.3))
                                            .frame(width: 40, height: 4)
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.pink.opacity(0.2))
                                            .frame(width: 60, height: 4)
                                    }
                                    .padding(12)
                                    .frame(width: 100, height: 60, alignment: .leading)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(12)
                                    .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
                                    
                                    // Hover X button overlapping the corner
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.pink)
                                        .font(.system(size: 18))
                                        .background(Circle().fill(Color(NSColor.windowBackgroundColor)).frame(width: 16, height: 16))
                                        .offset(x: -6, y: -6)
                                }
                            }
                        )
                        
                        ChangelogCard(
                            icon: "paintpalette.fill",
                            title: "Color System",
                            description: "Personalize your overlays with our new color system. Choose from enhanced presets to match your style.",
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
                        
                        ChangelogCard(
                            icon: "doc.on.clipboard.fill",
                            title: "Clipboard History UI",
                            description: "We've added a refined interface for managing your clipboard history, making it easier to access and use your recent clips.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.05))
                                
                                ZStack {
                                    // Background item
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                        .frame(width: 80, height: 40)
                                        .rotationEffect(.degrees(-8))
                                        .offset(x: -10, y: 15)
                                        .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                                        .overlay(
                                            HStack {
                                                Image(systemName: "photo").foregroundColor(.purple.opacity(0.5)).font(.system(size: 14))
                                                RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.2)).frame(width: 30, height: 4)
                                            }.padding(.horizontal, 10), alignment: .leading
                                        )
                                        
                                    // Middle item
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                        .frame(width: 80, height: 40)
                                        .rotationEffect(.degrees(4))
                                        .offset(x: 15, y: -5)
                                        .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                                        .overlay(
                                            HStack {
                                                Image(systemName: "link").foregroundColor(.blue.opacity(0.5)).font(.system(size: 14))
                                                RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.2)).frame(width: 40, height: 4)
                                            }.padding(.horizontal, 10), alignment: .leading
                                        )
                                        
                                    // Front item
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                        .frame(width: 90, height: 45)
                                        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                                        .overlay(
                                            HStack {
                                                Image(systemName: "text.alignleft").foregroundColor(.orange.opacity(0.8)).font(.system(size: 14))
                                                VStack(alignment: .leading, spacing: 4) {
                                                    RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.6)).frame(width: 45, height: 4)
                                                    RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.3)).frame(width: 30, height: 4)
                                                }
                                            }.padding(.horizontal, 12), alignment: .leading
                                        )
                                }
                            }
                        )
                        
                        ChangelogCard(
                            icon: "ladybug.fill",
                            title: "Bug Fixes & Optimizations",
                            description: "Resolved background Wi-Fi crashes, fixed headphone audio balance shifts, addressed overlay artifacts, and heavily optimized the app for a smoother experience.",
                            preview: ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green.opacity(0.05))
                                
                                ZStack {
                                    // Background abstract code
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                        .frame(width: 80, height: 60)
                                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                                        .overlay(
                                            VStack(alignment: .leading, spacing: 6) {
                                                RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.2)).frame(width: 50, height: 4)
                                                RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.2)).frame(width: 30, height: 4)
                                                RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.2)).frame(width: 40, height: 4)
                                            }.padding(12), alignment: .topLeading
                                        )
                                        .rotationEffect(.degrees(-8))
                                        .offset(x: -10, y: 5)
                                        
                                    // Floating magnifying glass focusing on the code
                                    ZStack {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 48, weight: .thin))
                                            .foregroundColor(.primary.opacity(0.7))
                                            
                                        // The checkmark and glow grouped to center inside the lens
                                        ZStack {
                                            Circle()
                                                .fill(Color.green.opacity(0.15)) // The glass lens glow
                                                .frame(width: 32, height: 32)
                                                .blur(radius: 4)
                                                
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.green)
                                        }
                                        .offset(x: -5, y: -5) // Adjusted centering over the magnifying glass lens
                                    }
                                    .shadow(color: .black.opacity(0.15), radius: 5, y: 4)
                                    .offset(x: 5, y: -5)
                                }
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
            }
            .padding(32)
        }
        .navigationTitle("Changelog")
    }
}

// MARK: - Components

struct ChangelogCard<Preview: View>: View {
    let icon: String
    let title: String
    let description: String
    let preview: Preview
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Preview Area
            ZStack {
                Color.primary.opacity(0.04)
                
                preview
            }
            .frame(height: 140)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
            )
            
            // Text Area
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundColor(.secondary)
                        .font(.system(size: 14, weight: .semibold))
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                }
                
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
