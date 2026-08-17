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
            showProgressBar: false,
            progress: 0,
            hasTimeoutProgress: true,
            isExpandable: false,
            keepAliveId: "fan",
            baseContent: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "fanblades.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 24)
                    
                    Text("Fan")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer(minLength: 8)
                    
                    Text(actualIsRunning ? "Running" : "Stopped")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
            },
            expandedContent: {
                EmptyView()
            }
        )
        .padding(20)
        .applyTheme(mediaKeyManager.overlayTheme)
    }
}
