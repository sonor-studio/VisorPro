import SwiftUI

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    var allowShrink: Bool = false
    var isCopyable: Bool = false
    var disableCopy: Bool = false
    var actionColor: Color = .green
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
                        .foregroundColor(copied ? actionColor : .secondary.opacity(0.7))
                        .frame(width: 14)
                        .transition(.scale.combined(with: .opacity))
                        .id(copied ? "check" : "copy")
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isCopyable && !disableCopy {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(value, forType: .string)
                onCopy?()
                withAnimation(.easeInOut(duration: 0.2)) {
                    copied = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        copied = false
                    }
                }
            }
        }
        .conditionalPointingHandCursor(isEnabled: isCopyable && !disableCopy)
        .help((isCopyable && !disableCopy) ? "Copy to clipboard" : "")
    }
}

struct WiFiOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @EnvironmentObject var overlayState: OverlayStateRelay
    @AppStorage("wifiAllowExpansion") private var wifiAllowExpansion: Bool = true
    @AppStorage("wifiShowSpeedTest") private var wifiShowSpeedTest: Bool = true
    @AppStorage("wifiShowDetails") private var wifiShowDetails: Bool = true
    @State private var isExpanded: Bool = false
    @State private var refreshTimer: Timer?
    @State private var isTestingSpeed: Bool = false
    @State private var speedTestResult: NetworkQualityResult? = nil
    @State private var showDetails: Bool = false
    @State private var testFailed: Bool = false
    var isPreview: Bool = false
    var previewIsConnected: Bool = true
    var previewSSID: String = "My Wi-Fi"
    
    private var actualIsConnected: Bool {
        isPreview ? previewIsConnected : overlayState.wiFiIsConnected
    }
    
    private var actualSSID: String {
        isPreview ? previewSSID : overlayState.wiFiSSID
    }
    
    private var actualIsHotspot: Bool {
        isPreview ? false : overlayState.wiFiIsHotspot
    }
    
    private var actionColor: Color {
        actualIsConnected ? OverlayColorManager.shared.getOverlayColor(for: "colorOnWiFiConnect", defaultColor: .blue) : .offStateGray
    }
    
    private var actionTitle: String {
        if actualIsConnected {
            return actualIsHotspot ? "Hotspot Connected" : "Wi-Fi Connected"
        } else {
            return actualIsHotspot ? "Hotspot Disconnected" : "Wi-Fi Disconnected"
        }
    }
    
    var body: some View {
        
        let iconName = actualIsConnected ? (actualIsHotspot ? "personalhotspot" : "wifi") : "wifi.slash"
        let wifiPos = MediaKeyManager.shared.getOverlayPosition(for: "wifiOverlayPosition")
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            hasTimeoutProgress: true,
            timeoutEventId: overlayState.wiFiEventId,
            barColor: actualIsConnected ? OverlayColorManager.shared.getOverlayColor(for: "colorOnWiFiConnect", defaultColor: .blue) : .offStateGray,
            fillCenter: false,
            isMuted: false,
            customWidth: 260,
            customHeight: 56,
            supportDragGesture: false,
            onSimpleTap: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if !isExpanded && actualIsConnected && !overlayState.wiFiDetailsFetched {
                        mediaKeyManager.fetchWiFiDetails()
                    }
                }
            },
            isExpandable: wifiAllowExpansion,
            expandUpwards: wifiPos.hasPrefix("bottom"),
            keepAliveId: "wifi",
            baseContent: {
                HStack(alignment: .top, spacing: 0) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(actualIsConnected ? .primary : .secondary)
                        .frame(width: 26, height: 24)
                        .padding(.leading, 16 + 4 + 3)
                        .padding(.top, 4)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(actionTitle)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.leading, 14)
                            .padding(.trailing, 16 + 4 + 3)
                        
                        MarqueeText(text: actualSSID.isEmpty ? "No Network" : actualSSID, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                            .padding(.leading, 14)
                            .padding(.trailing, 16 + 4 + 3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 5)
            },
            expandedContent: {
                VStack(spacing: 12) {
                    Divider()
                        .onAppear {
                            if actualIsConnected && speedTestResult == nil && !testFailed && !isPreview && wifiShowSpeedTest {
                                startSpeedTest()
                            }
                        }
                        .padding(.horizontal, 16)
                        .opacity(0.5)
                    
                    if !isPreview && !overlayState.wiFiDetailsFetched && actualIsConnected {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(height: 50)
                    } else {
                        if actualIsConnected {
                            // Speed Test UI
                            if wifiShowSpeedTest {
                            VStack(spacing: 8) {
                                if isTestingSpeed {
                                    HStack(alignment: .lastTextBaseline) {
                                        Text("Running Speed Test...")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        ProgressView()
                                            .scaleEffect(0.5)
                                            .frame(width: 12, height: 12)
                                    }
                                } else if testFailed {
                                    HStack(alignment: .center) {
                                        Text("Speed Test Failed")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundColor(.red)
                                        Spacer()
                                        Button(action: { startSpeedTest() }) {
                                            Text("Retry")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(actionColor)
                                                .cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                        .pointingHandCursor()
                                    }
                                } else {
                                    HStack(alignment: .lastTextBaseline) {
                                        Text(speedTestResult != nil ? "Speed Test Complete" : "Speed Test Ready")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        if speedTestResult != nil {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(actionColor)
                                        }
                                    }
                                }
                                
                                HStack(spacing: 8) {
                                    // DOWNLOAD
                                    VStack(alignment: .center, spacing: 4) {
                                        Text("Download")
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                        
                                        if let result = speedTestResult {
                                            let dlMbps = (result.dl_throughput ?? 0) / 1_000_000
                                            Text("\(String(format: "%.1f", dlMbps))")
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                        } else {
                                            Text("--")
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        
                                        Text("Mbps")
                                            .font(.system(size: 9, weight: .medium, design: .rounded))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    
                                    Divider().frame(height: 24)
                                    
                                    // UPLOAD
                                    VStack(alignment: .center, spacing: 4) {
                                        Text("Upload")
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                        
                                        if let result = speedTestResult {
                                            let ulMbps = (result.ul_throughput ?? 0) / 1_000_000
                                            Text("\(String(format: "%.1f", ulMbps))")
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                        } else {
                                            Text("--")
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        
                                        Text("Mbps")
                                            .font(.system(size: 9, weight: .medium, design: .rounded))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    
                                    Divider().frame(height: 24)
                                    
                                    // PING
                                    VStack(alignment: .center, spacing: 4) {
                                        Text("Ping")
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                        
                                        if let ping = speedTestResult?.base_rtt {
                                            Text("\(Int(ping))")
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                        } else {
                                            Text("--")
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        
                                        Text("ms")
                                            .font(.system(size: 9, weight: .medium, design: .rounded))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                }
                                .padding(.vertical, 8)
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(8)
                            }
                            .padding(.horizontal, 16)
                            } // End of wifiShowSpeedTest
                            
                            if wifiShowSpeedTest && wifiShowDetails {
                            // Show Details button
                            HStack {
                                Spacer()
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showDetails.toggle()
                                    }
                                }) {
                                    Text(showDetails ? "Hide Details" : "Show Details")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(Color.primary.opacity(0.1))
                                        .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                                .pointingHandCursor()
                                Spacer()
                            }
                            .padding(.top, 4)
                            
                            }
                            if wifiShowDetails {
                                if !wifiShowSpeedTest || showDetails {
                                    statsView
                                }
                            }
                            
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
                                .pointingHandCursor()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                        } else {
                            HStack(spacing: 8) {
                                Button(action: {
                                    if !isPreview {
                                        mediaKeyManager.openNetworkSettings()
                                        withAnimation(.easeInOut(duration: 0.2)) {
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
                                .pointingHandCursor()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                        }
                    }
                }
            }
        )
        .id(overlayState.wiFiEventId)
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                    mediaKeyManager.fetchDynamicWiFiDetails()
                }
                if actualIsConnected && speedTestResult == nil && !testFailed && !isPreview {
                    startSpeedTest()
                }
            } else {
                refreshTimer?.invalidate()
                refreshTimer = nil
            }
        }
    }
    

    private func startSpeedTest() {
        guard !isTestingSpeed && !isPreview else { return }
        isTestingSpeed = true
        speedTestResult = nil
        testFailed = false
        
        Task {
            do {
                let result = try await NetworkSpeedManager.shared.runSpeedTest()
                DispatchQueue.main.async {
                    withAnimation(.linear(duration: 0.2)) {
                        self.speedTestResult = result
                        self.isTestingSpeed = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    withAnimation(.linear(duration: 0.2)) {
                        self.testFailed = true
                        self.isTestingSpeed = false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statsView: some View {
        VStack(spacing: 8) {
            if let ip = isPreview ? "192.168.1.12" : overlayState.wiFiIPAddress {
                StatRow(icon: "network", label: "IP Address", value: ip, isCopyable: true, disableCopy: isPreview, actionColor: actionColor, onCopy: {
                    if !isPreview {
                        mediaKeyManager.pendingClipboardAction = "ignore"
                        mediaKeyManager.pendingClipboardActionTimestamp = Date()
                    }
                })
            }
            
            if let txRate = isPreview ? 866.0 : overlayState.wiFiTxRate {
                StatRow(icon: "bolt.horizontal", label: "Tx Rate", value: "\(Int(txRate)) Mbps")
            }
            if let rssi = isPreview ? -52 : overlayState.wiFiRSSI {
                StatRow(icon: "antenna.radiowaves.left.and.right", label: "Signal", value: "\(rssi) dBm")
            }
            if let channel = isPreview ? "44 (5 GHz)" : overlayState.wiFiChannel {
                StatRow(icon: "radio", label: "Channel", value: channel)
            }
        }
        .padding(.horizontal, 16)
    }
}
