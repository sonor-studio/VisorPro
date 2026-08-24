import SwiftUI

struct RamOverlayView: View {
    @State private var isHovering: Bool = false
    @State private var isExpanded: Bool = false
    @AppStorage("ramOverlayPosition") private var ramOverlayPosition: String = "bottom"
    
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    var isPreview: Bool = false
    
    var body: some View {
        let percent = isPreview ? 95.0 : mediaKeyManager.ramUsagePercent
        let used = isPreview ? 15.2 : mediaKeyManager.usedRamGB
        let total = isPreview ? 16.0 : mediaKeyManager.totalRamGB
        let history = isPreview ? [62.0, 65.0, 68.0, 72.0, 70.0, 75.0, 78.0, 82.0, 80.0, 85.0, 88.0, 91.0, 89.0, 93.0, 95.0, 95.0] : mediaKeyManager.ramUsageHistory
        let processes = isPreview ? [
            ("Google Chrome", 2.5),
            ("Xcode", 1.8),
            ("WindowServer", 0.9),
            ("Docker", 0.5),
            ("Terminal", 0.2)
        ] : mediaKeyManager.ramTopProcesses
        
        let trackWidth: CGFloat = 260 - 8
        let isCritical = percent >= 90.0
        let chartColor: Color = isCritical ? .red : .orange
        let barColor: Color = isCritical ? .red : .orange
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            progress: percent / 100.0,
            customProgressMask: AnyView(
                TimeoutProgressBar(trackWidth: trackWidth, isHovering: isHovering || isExpanded || mediaKeyManager.globalHoveredTypes.contains("ram"), initialDuration: MediaKeyManager.notificationDuration, hoverOutDuration: MediaKeyManager.notificationDuration)
                    .id(mediaKeyManager.ramEventId)
            ),
            barColor: barColor,
            fillCenter: false,
            isMuted: false,
            supportDragGesture: false,
            onSimpleTap: {
                if !isPreview {
                    mediaKeyManager.keepAlive(for: "ram", isHovering: true)
                }
            },
            isExpandable: true,
            expandUpwards: ramOverlayPosition == "bottom",
            keepAliveId: "ram",
            baseContent: {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 24)
                        .padding(.leading, 16)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("RAM Usage")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        HStack(alignment: .bottom, spacing: 4) {
                            Text(String(format: "%.1f", used))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                            Text(String(format: "/ %.1f GB", total))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .padding(.bottom, 1)
                            Text(String(format: "(%.0f%%)", percent))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .padding(.bottom, 1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            },
            expandedContent: {
                VStack(spacing: 8) {
                    // Wykres historii użycia RAMu
                    RamChartView(history: history, color: chartColor)
                        .frame(height: 35)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 4)
                        
                    Divider()
                        .padding(.horizontal, 16)
                        .opacity(0.5)
                        
                    ForEach(Array(processes.enumerated()), id: \.offset) { index, process in
                        HStack {
                            Text(process.0)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer()
                            Text(String(format: "%.2f GB", process.1))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        )
        .onHover { hover in
            isHovering = hover
            if !isPreview {
                mediaKeyManager.keepAlive(for: "ram", isHovering: hover)
            }
        }
    }
}
