import SwiftUI

struct FanOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @StateObject private var fanObserver = FanObserver.shared
    @State private var isExpanded = false
    
    var isPreview: Bool = false
    var previewIsRunning: Bool = false
    
    private var actualIsRunning: Bool {
        isPreview ? previewIsRunning : fanObserver.isFanRunning
    }
    
    var body: some View {
        UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            progress: 1.0,
            hasTimeoutProgress: true,
            timeoutEventId: mediaKeyManager.fanEventId,
            barColor: actualIsRunning ? Color(red: 0.55, green: 0.8, blue: 1.0) : .secondary,
            fillCenter: false,
            isExpandable: false,
            keepAliveId: "fan",
            baseContent: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "fanblades.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(actualIsRunning ? .primary : .secondary)
                        .frame(width: 26, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(actualIsRunning ? "Running" : "Stopped")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Text("Fan")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
            },
            expandedContent: {
                EmptyView()
            }
        )
        .id(mediaKeyManager.fanEventId)
    }
}
