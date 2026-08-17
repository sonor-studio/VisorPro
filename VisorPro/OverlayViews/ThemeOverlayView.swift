import SwiftUI

struct ThemeOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering: Bool = false
    
    var isPreview: Bool = false
    var previewIsDark: Bool = false
    
    var body: some View {
        let titleText: String
        let iconName: String
        let iconColor: Color
        
        if isPreview {
            if previewIsDark {
                titleText = "Dark Theme"
                iconName = "moon.fill"
                iconColor = .indigo
            } else {
                titleText = "Light Theme"
                iconName = "sun.max.fill"
                iconColor = .orange
            }
        } else {
            if mediaKeyManager.isDarkMode {
                titleText = "Dark Mode"
                iconName = "moon.fill"
                iconColor = .indigo
            } else {
                titleText = "Light Mode"
                iconName = "sun.max.fill"
                iconColor = .orange
            }
        }
        let trackWidth: CGFloat = 230 - 8
        

        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: .constant(false),
            showProgressBar: true,
            progress: 1.0,
            customProgressMask: AnyView(
                TimeoutProgressBar(trackWidth: trackWidth, isHovering: isHovering || mediaKeyManager.globalHoveredTypes.contains("theme"), initialDuration: MediaKeyManager.notificationDuration, hoverOutDuration: MediaKeyManager.notificationDuration)
                    .id(mediaKeyManager.themeEventId)
            ),
            barColor: iconColor,
            fillCenter: false, // uses strokeBorder in original
            isMuted: false,
            listHeight: 0,
            customWidth: 230,
            supportDragGesture: false,
            baseContent: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Theme")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        MarqueeText(text: titleText, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                    }
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16 + 4 + 3)
            },
            expandedContent: {
                EmptyView()
            }
        )
        .frame(width: 230, height: 56, alignment: .top)

        .padding(20)
        .onHoverExact { hovering in
            if !isPreview {
                self.isHovering = hovering
                mediaKeyManager.keepAlive(for: "theme", isHovering: hovering)
            }
        }
        .applyTheme(mediaKeyManager.overlayTheme)
        .simultaneousGesture(TapGesture().onEnded {
            if !isPreview {
                toggleSystemTheme()
            }
        })
    }
    
    private func toggleSystemTheme() {
        DispatchQueue.global(qos: .userInitiated).async {
            let scriptSource = """
            tell application "System Events"
                tell appearance preferences
                    set dark mode to not dark mode
                end tell
            end tell
            """
            if let script = NSAppleScript(source: scriptSource) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
                if let error = error {
                    print("Failed to toggle theme: \(error)")
                }
            }
        }
    }
}
