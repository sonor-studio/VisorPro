import SwiftUI

struct CpuTemperatureOverlayView: View {
    @State private var isExpanded: Bool = false
    
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    var isPreview: Bool = false
    
    var body: some View {
        let temp = isPreview ? 65.0 : mediaKeyManager.cpuTemperature
        let history = isPreview ? [40.0, 45.0, 50.0, 60.0, 65.0, 70.0, 68.0, 65.0] : mediaKeyManager.cpuTempHistory
        
        // Celsjusze
        let tempString = String(format: "%.1f°C", temp)
        
        let isCritical = temp >= 80.0
        let chartColor: Color = isCritical ? .red : .orange
        let barColor: Color = isCritical ? .red : .orange
        let trackWidth: CGFloat = 260 - 8
        let cpuPos = MediaKeyManager.shared.getOverlayPosition(for: "cpuOverlayPosition")
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            progress: temp / 100.0,
            customProgressMask: AnyView(
                TimeoutProgressBar(trackWidth: trackWidth, isHovering: isExpanded || mediaKeyManager.globalHoveredTypes.contains("cpu"), initialDuration: MediaKeyManager.notificationDuration, hoverOutDuration: MediaKeyManager.notificationDuration, isPreview: isPreview)
                    .id(mediaKeyManager.cpuEventId)
            ),
            barColor: barColor,
            fillCenter: false,
            isMuted: false,
            supportDragGesture: false,
            onSimpleTap: {
                if !isPreview {
                    mediaKeyManager.keepAlive(for: "cpu", isHovering: true)
                }
            },
            isExpandable: true,
            expandUpwards: cpuPos.hasPrefix("bottom"),
            keepAliveId: "cpu",
            baseContent: {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "thermometer")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 24)
                        .padding(.leading, 16)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CPU Temp")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Text(tempString)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.trailing, 16)
            },
            expandedContent: {
                let getIcon = { (name: String) -> NSImage? in
                    if let path = NSWorkspace.shared.perform(NSSelectorFromString("fullPathForApplication:"), with: name)?.takeUnretainedValue() as? String {
                        return NSWorkspace.shared.icon(forFile: path)
                    }
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: name) {
                        return NSWorkspace.shared.icon(forFile: url.path)
                    }
                    return nil
                }
                let processes = isPreview ? [
                    ("Final Cut Pro", 45.2, NSImage(named: "PreviewFinalCut") ?? getIcon("com.apple.FinalCut")),
                    ("Logic Pro", 32.5, NSImage(named: "PreviewLogicPro") ?? getIcon("com.apple.logic10")),
                    ("WindowServer", 18.1, NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: nil)),
                    ("Xcode", 12.4, NSImage(named: "PreviewXcode") ?? getIcon("com.apple.dt.Xcode")),
                    ("kernel_task", 5.2, NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: nil))
                ] : mediaKeyManager.cpuTopProcesses
                
                VStack(spacing: 8) {
                    RamChartView(history: history, color: chartColor, unit: "°C", timeLabel: "-1m")
                        .frame(height: 55)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 4)
                        
                    if !processes.isEmpty {
                        Divider()
                            .padding(.horizontal, 16)
                            .opacity(0.5)
                        
                        VStack(spacing: 6) {
                            ForEach(Array(processes.enumerated()), id: \.offset) { index, process in
                                HStack {
                                    if let icon = process.2 {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 14, height: 14)
                                    }
                                    Text(process.0)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    Spacer()
                                    Text(String(format: "%.1f%%", process.1))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
                .padding(.bottom, 8)
            }
        )
    }
}
