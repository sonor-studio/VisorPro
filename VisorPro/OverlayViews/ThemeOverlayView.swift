import SwiftUI

struct ThemeOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("themeAllowInteractivity") private var themeAllowInteractivity: Bool = true
    
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
                iconColor = Color(red: 0.45, green: 0.5, blue: 0.9)
            } else {
                titleText = "Light Theme"
                iconName = "sun.max.fill"
                iconColor = Color(red: 1.0, green: 0.72, blue: 0.0)
            }
        } else {
            if mediaKeyManager.isDarkMode {
                titleText = "Dark Mode"
                iconName = "moon.fill"
                iconColor = Color(red: 0.45, green: 0.5, blue: 0.9)
            } else {
                titleText = "Light Mode"
                iconName = "sun.max.fill"
                iconColor = Color(red: 1.0, green: 0.72, blue: 0.0)
            }
        }
        

        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: .constant(false),
            showProgressBar: true,
            hasTimeoutProgress: true,
            timeoutEventId: mediaKeyManager.themeEventId,
            barColor: iconColor,
            fillCenter: false, // It was using strokeBorder
            isMuted: false,
            customWidth: 230,
            supportDragGesture: false,
            onSimpleTap: {
                if !isPreview && themeAllowInteractivity {
                    toggleSystemTheme()
                }
            },
            isExpandable: false,
            keepAliveId: "theme",
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
        .id(mediaKeyManager.themeEventId)
        .frame(width: 230, height: 56, alignment: .top)
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
                if error != nil {
                }
            }
        }
    }
}
