import SwiftUI

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    var allowShrink: Bool = false
    var isCopyable: Bool = false
    var disableCopy: Bool = false
    var onCopy: (() -> Void)? = nil
    
    @State private var copied: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 16)
                .foregroundColor(.secondary)
                .font(.system(size: 11, weight: .semibold))
            
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 6) {
                if allowShrink {
                    Text(value)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    Text(value)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                if isCopyable {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(copied ? .green : .secondary.opacity(0.7))
                        .frame(width: 14)
                        .transition(.scale.combined(with: .opacity))
                        .id(copied ? "check" : "copy")
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isCopyable && !disableCopy {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(value, forType: .string)
                    onCopy?()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        copied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            copied = false
                        }
                    }
                }
            }
            .help((isCopyable && !disableCopy) ? "Copy to clipboard" : "")
        }
    }
}

struct WiFiOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @State private var isExpanded: Bool = false
    @State private var refreshTimer: Timer?
    var isPreview: Bool = false
    var previewIsConnected: Bool = true
    var previewSSID: String = "My Wi-Fi"
    
    private var actualIsConnected: Bool {
        isPreview ? previewIsConnected : mediaKeyManager.wiFiIsConnected
    }
    
    private var actualSSID: String {
        isPreview ? previewSSID : mediaKeyManager.wiFiSSID
    }
    
    private var actualIsHotspot: Bool {
        isPreview ? false : mediaKeyManager.wiFiIsHotspot
    }
    
    private var actionColor: Color {
        actualIsConnected ? .cyan : .secondary
    }
    
    private var actionTitle: String {
        if actualIsConnected {
            return actualIsHotspot ? "Hotspot Connected" : "Wi-Fi Connected"
        } else {
            return actualIsHotspot ? "Hotspot Disconnected" : "Wi-Fi Disconnected"
        }
    }
    
    var body: some View {
        let actionColor: Color = actualIsConnected ? .cyan : .secondary
        
        let listHeight: CGFloat = actualIsConnected ? 160 : 70
        let iconName = actualIsConnected ? (actualIsHotspot ? "personalhotspot" : "wifi") : "wifi.slash"
        let wifiPos = UserDefaults.standard.string(forKey: "wifiOverlayPosition") ?? "bottom"
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            hasTimeoutProgress: true,
            timeoutEventId: mediaKeyManager.wiFiEventId,
            barColor: actionColor,
            fillCenter: false,
            isMuted: false,
            listHeight: listHeight,
            customWidth: 260,
            customHeight: 56,
            supportDragGesture: false,
            onSimpleTap: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    if !isExpanded && actualIsConnected && !mediaKeyManager.wiFiDetailsFetched {
                        mediaKeyManager.fetchWiFiDetails()
                    }
                }
            },
            isExpandable: true,
            expandUpwards: wifiPos == "bottom",
            keepAliveId: "wifi",
            baseContent: {
                HStack(alignment: .top, spacing: 0) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(actualIsConnected ? .primary : .secondary)
                        .frame(width: 26, height: 24)
                        .padding(.leading, 16)
                        .padding(.top, 4)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(actionTitle)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.leading, 14)
                            .padding(.trailing, 16)
                        
                        MarqueeText(text: actualSSID.isEmpty ? "No Network" : actualSSID, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                            .padding(.leading, 14)
                            .padding(.trailing, 16)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 5)
            },
            expandedContent: {
                VStack(spacing: 12) {
                    Divider()
                        .padding(.horizontal, 16)
                        .opacity(0.5)
                    
                    if !isPreview && !mediaKeyManager.wiFiDetailsFetched && actualIsConnected {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(height: 50)
                    } else {
                        if actualIsConnected {
                            statsView
                            
                            HStack(spacing: 8) {
                                Button(action: {
                                    if !isPreview {
                                        mediaKeyManager.disconnectWiFi()
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "wifi.slash")
                                        Text("Disconnect")
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.red.opacity(0.15))
                                    .cornerRadius(28 - 4 - 3)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                            .padding(.top, 4)
                        } else {
                            HStack(spacing: 8) {
                                Button(action: {
                                    if !isPreview {
                                        mediaKeyManager.openNetworkSettings()
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                            isExpanded = false
                                        }
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "gear")
                                        Text("Network Settings")
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.primary.opacity(0.1))
                                    .cornerRadius(28 - 4 - 3)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                            .padding(.top, 4)
                        }
                    }
                }
            }
        )

        .padding(20)
        .applyTheme(mediaKeyManager.overlayTheme)
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                    mediaKeyManager.fetchDynamicWiFiDetails()
                }
            } else {
                refreshTimer?.invalidate()
                refreshTimer = nil
            }
        }
    }
    
    @ViewBuilder
    private var statsView: some View {
        VStack(spacing: 8) {
            if let ip = isPreview ? "192.168.1.12" : mediaKeyManager.wiFiIPAddress {
                StatRow(icon: "network", label: "IP Address", value: ip, isCopyable: true, disableCopy: isPreview, onCopy: {
                    if !isPreview {
                        mediaKeyManager.pendingClipboardActionTimestamp = Date()
                    }
                })
            }
            if let txRate = isPreview ? 866.0 : mediaKeyManager.wiFiTxRate {
                StatRow(icon: "bolt.horizontal", label: "Tx Rate", value: "\(Int(txRate)) Mbps")
            }
            if let rssi = isPreview ? -52 : mediaKeyManager.wiFiRSSI {
                StatRow(icon: "antenna.radiowaves.left.and.right", label: "Signal", value: "\(rssi) dBm")
            }
            if let channel = isPreview ? "44 (5 GHz)" : mediaKeyManager.wiFiChannel {
                StatRow(icon: "radio", label: "Channel", value: channel)
            }
        }
        .padding(.horizontal, 16)
    }
}
