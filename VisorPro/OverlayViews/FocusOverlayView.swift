import SwiftUI

struct FocusOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    
    var isPreview: Bool = false
    var previewIsActive: Bool = false
    var previewModeName: String = "Praca"
    
    private func getColor(from name: String) -> Color {
        switch name {
        case "systemMintColor": return .mint
        case "systemGreenColor": return .green
        case "systemIndigoColor": return .indigo
        case "systemTealColor": return .teal
        case "systemPurpleColor": return .purple
        case "systemBlueColor": return .blue
        case "systemOrangeColor": return .orange
        case "systemRedColor": return .red
        case "systemYellowColor": return .yellow
        case "systemPinkColor": return .pink
        default: return Color(red: 0.45, green: 0.5, blue: 0.9) // Default Indigo-ish
        }
    }
    
    @State private var isExpanded: Bool = false
    
    private func getEndDateString(date: Date?) -> String? {
        guard let date = date else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func getDurationString(start: Date?, end: Date?) -> String {
        guard let start = start, let end = end else { return "0m" }
        let duration = max(0, end.timeIntervalSince(start))
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0m"
    }
    
    var body: some View {
        let iconName: String
        let iconColor: Color
        let active: Bool
        let modeName: String
        
        if isPreview {
            active = previewIsActive
            modeName = previewModeName
            iconName = "moon.fill"
            iconColor = getColor(from: "systemIndigoColor")
        } else {
            active = mediaKeyManager.isFocusModeActive
            modeName = mediaKeyManager.focusModeName
            iconName = mediaKeyManager.focusSymbol
            iconColor = getColor(from: mediaKeyManager.focusColorName)
        }
        
        let displayTitle: String
        let displayIcon: String
        let displayColor: Color
        
        if active {
            if isPreview {
                displayTitle = "Focus On"
            } else {
                displayTitle = mediaKeyManager.isFocusSwitched ? "Focus Switched" : (mediaKeyManager.isFocusReminder ? "Focus Reminder" : "Focus On")
            }
            displayIcon = iconName
            displayColor = iconColor
        } else {
            displayTitle = "Focus Off"
            displayIcon = "moon.zzz" 
            displayColor = Color(NSColor.secondaryLabelColor)
        }
        
        let details: MediaKeyManager.ActiveFocusDetails?
        let lastEnded: MediaKeyManager.ActiveFocusDetails?
        
        if isPreview {
            if UserDefaults.standard.bool(forKey: "focusDetailMode") {
                let start = Date().addingTimeInterval(-3600)
                let end = Date().addingTimeInterval(3600)
                if active {
                    details = MediaKeyManager.ActiveFocusDetails(startDate: start, endDate: end, source: "com.apple.focus", device: "This Mac", untilLocationLeft: false, endedAt: nil, endedReason: nil)
                    lastEnded = nil
                } else {
                    details = nil
                    lastEnded = MediaKeyManager.ActiveFocusDetails(startDate: start, endDate: end, source: "com.apple.focus", device: "This Mac", untilLocationLeft: false, endedAt: Date(), endedReason: "turned off")
                }
            } else {
                details = nil
                lastEnded = nil
            }
        } else {
            details = mediaKeyManager.activeFocusDetails
            lastEnded = mediaKeyManager.lastEndedFocusDetails
        }
        
        let isExpandable = (active && details != nil) || (!active && lastEnded != nil)
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            hasTimeoutProgress: true,
            timeoutEventId: mediaKeyManager.focusEventId,
            barColor: displayColor,
            fillCenter: false,
            isMuted: false,
            customWidth: 240,
            supportDragGesture: false,
            onSimpleTap: {},
            isExpandable: isExpandable,
            keepAliveId: "focus",
            baseContent: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: displayIcon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(displayColor)
                        .frame(width: 26, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if active && details != nil && mediaKeyManager.isFocusReminder, let startDate = details?.startDate {
                            HStack(spacing: 4) {
                                Text(displayTitle)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                Text("•")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                if isPreview {
                                    Text("1:02:15")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(startDate, style: .timer)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundColor(.secondary)
                                }
                            }
                            MarqueeText(text: modeName, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                        } else if active && details != nil && !mediaKeyManager.isFocusReminder && !mediaKeyManager.isFocusSwitched {
                            if let endDate = details?.endDate, let timeStr = getEndDateString(date: endDate) {
                                HStack(spacing: 4) {
                                    Text(displayTitle)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(.secondary)
                                    Text("•")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.secondary)
                                    Text("until \(timeStr)")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                MarqueeText(text: modeName, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                            } else if details?.untilLocationLeft == true {
                                HStack(spacing: 4) {
                                    Text(displayTitle)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(.secondary)
                                    Text("•")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.secondary)
                                    Text("until I leave")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                MarqueeText(text: modeName, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                            } else {
                                Text(displayTitle)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                MarqueeText(text: modeName, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                            }
                        } else {
                            Text(displayTitle)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                            MarqueeText(text: modeName, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                        }
                    }
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16 + 4 + 3)
            },
            expandedContent: {
                if active, let details = details {
                    HStack(spacing: 0) {
                        if let startDate = details.startDate {
                            VStack(alignment: .center, spacing: 4) {
                                Text("Active For")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                if isPreview {
                                    Text("1:02:15")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                } else {
                                    Text(startDate, style: .timer)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        
                        if let endDate = details.endDate {
                            Divider()
                                .frame(height: 24)
                            
                            VStack(alignment: .center, spacing: 4) {
                                Text("Time Left")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                if isPreview {
                                    Text("57:45")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                } else {
                                    Text(endDate, style: .timer)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        } else if details.untilLocationLeft {
                            Divider()
                                .frame(height: 24)
                            
                            VStack(alignment: .center, spacing: 4) {
                                Text("Until")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                Text("Leaving")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        
                        if let device = details.device {
                            Divider()
                                .frame(height: 24)
                            
                            VStack(alignment: .center, spacing: 4) {
                                Text("Triggered By")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                Text(device)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .padding(.top, 12)
                } else if !active, let lastEnded = lastEnded {
                    if let start = lastEnded.startDate, let end = lastEnded.endedAt {
                        let durStr = getDurationString(start: start, end: end)
                        
                        VStack(alignment: .center, spacing: 2) {
                            Text("Active For")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Text(durStr)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .padding(.top, 4)
                    }
                } else {
                    EmptyView()
                }
            }
        )
        .id(mediaKeyManager.focusEventId)
        .frame(width: 240, alignment: .top)
    }
}
