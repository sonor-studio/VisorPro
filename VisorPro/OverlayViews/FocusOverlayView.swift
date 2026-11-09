import SwiftUI

struct FocusOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @EnvironmentObject var overlayState: OverlayStateRelay
    @AppStorage("focusAllowExpansion") private var focusAllowExpansion: Bool = true
    
    var isPreview: Bool = false
    var previewIsActive: Bool = false
    var previewModeName: String = "Praca"
    
    private func getColor(from name: String) -> Color {
        if mediaKeyManager.overlayColorMode == "preset_monochrome" {
            return OverlayColorManager.shared.parseColor("White/Black")
        }
        switch name {
        case "appleIntelligenceColor", "reduceInterruptionsColor":
            return Color(red: 203.0 / 255.0, green: 48.0 / 255.0, blue: 224.0 / 255.0) // Apple Intelligence neon magenta-purple (#CB30E0)
        case "systemMintColor": return Color(red: 0.0, green: 0.78, blue: 0.74)
        case "systemGreenColor": return Color(red: 0.20, green: 0.78, blue: 0.35)
        case "systemIndigoColor": return Color(nsColor: .systemIndigo) // Apple Focus authentic Indigo / Violet
        case "systemTealColor": return Color(red: 0.18, green: 0.67, blue: 0.82)
        case "systemPurpleColor": return Color(red: 0.68, green: 0.32, blue: 0.87)
        case "systemBlueColor": return Color(red: 0.04, green: 0.52, blue: 1.0)
        case "systemOrangeColor": return Color(red: 1.0, green: 0.58, blue: 0.0)
        case "systemRedColor": return Color(red: 1.0, green: 0.27, blue: 0.23)
        case "systemYellowColor": return Color(red: 1.0, green: 0.80, blue: 0.0)
        case "systemPinkColor": return Color(red: 1.0, green: 0.18, blue: 0.45)
        default: return Color(nsColor: .systemIndigo)
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
        let totalSeconds = max(0, Int(end.timeIntervalSince(start)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(max(0, totalSeconds))s"
        }
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
            active = overlayState.displayedFocusModeActive
            modeName = overlayState.displayedFocusModeName
            iconName = overlayState.displayedFocusSymbol
            let rawColor = getColor(from: overlayState.displayedFocusColorName)
            if modeName.lowercased().contains("reduce") || modeName.lowercased() == "_gm" || iconName == "apple.intelligence" {
                iconColor = Color(red: 203.0 / 255.0, green: 48.0 / 255.0, blue: 224.0 / 255.0)
            } else {
                iconColor = rawColor
            }
        }
        
        let displayTitle: String
        let displayIcon: String
        let displayColor: Color
        let isReminder = active && (isPreview ? false : overlayState.isFocusReminder)
        
        let resolvedModeName: String = {
            let raw = modeName.trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.isEmpty || raw.lowercased() == "focus" {
                if !overlayState.lastActiveFocusModeName.isEmpty && overlayState.lastActiveFocusModeName.lowercased() != "focus" && overlayState.lastActiveFocusModeName.lowercased() != "_gm" {
                    return overlayState.lastActiveFocusModeName
                }
                return "Do Not Disturb"
            }
            if raw.lowercased() == "_gm" {
                return "Reduce Interruptions"
            }
            return raw
        }()
        
        let resolvedIcon: String = {
            if iconName.isEmpty || iconName == "moon.zzz" || iconName == "_gm" {
                if !overlayState.lastActiveFocusSymbol.isEmpty && overlayState.lastActiveFocusSymbol != "moon.zzz" && overlayState.lastActiveFocusSymbol != "_gm" {
                    return overlayState.lastActiveFocusSymbol
                }
                if resolvedModeName.lowercased().contains("reduce") {
                    return "apple.intelligence"
                }
                return "moon.fill"
            }
            return iconName
        }()
        
        if active {
            if isPreview {
                displayTitle = "Focus On"
            } else {
                displayTitle = overlayState.isFocusSwitched ? "Focus Switched" : (overlayState.isFocusReminder ? "Focus Reminder" : "Focus On")
            }
            displayIcon = resolvedIcon
            displayColor = iconColor
        } else {
            displayTitle = "Focus Off"
            displayIcon = resolvedIcon // Always show the focus mode's actual icon, matching native macOS
            displayColor = .offStateGray
        }
        
        let details: MediaKeyManager.ActiveFocusDetails?
        let lastEnded: MediaKeyManager.ActiveFocusDetails?
        
        if isPreview {
            let start = Date().addingTimeInterval(-3600)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd HH:mm"
            let end = formatter.date(from: "2030/01/01 20:00") ?? Date().addingTimeInterval(3600)
            if UserDefaults.standard.bool(forKey: "focusDetailMode") {
                if active {
                    details = MediaKeyManager.ActiveFocusDetails(startDate: start, endDate: end, source: "com.apple.focus", device: "This Mac", untilLocationLeft: false, endedAt: nil, endedReason: nil)
                    lastEnded = nil
                } else {
                    details = nil
                    lastEnded = MediaKeyManager.ActiveFocusDetails(startDate: start, endDate: end, source: "com.apple.focus", device: "This Mac", untilLocationLeft: false, endedAt: Date(), endedReason: "turned off")
                }
            } else {
                if active {
                    details = nil
                    lastEnded = nil
                } else {
                    details = nil
                    lastEnded = MediaKeyManager.ActiveFocusDetails(startDate: start, endDate: nil, source: "com.apple.focus", device: "This Mac", untilLocationLeft: false, endedAt: Date(), endedReason: "turned off")
                }
            }
        } else {
            details = overlayState.activeFocusDetails
            lastEnded = overlayState.lastEndedFocusDetails
        }
        
        let isExpandable = (active && (details != nil || overlayState.isFocusReminder)) || (!active && lastEnded != nil)
        let reminderDuration = getDurationString(
            start: details?.startDate ?? overlayState.focusActiveDate ?? Date().addingTimeInterval(-Double(mediaKeyManager.focusReminderInterval * 60)),
            end: Date()
        )
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            hasTimeoutProgress: true,
            timeoutEventId: overlayState.focusEventId,
            barColor: displayColor,
            fillCenter: false,
            isMuted: false,
            customWidth: (MediaKeyManager.shared.effectiveOverlayStyle == "system") ? 220 : 260,
            supportDragGesture: false,
            onSimpleTap: nil,
            isExpandable: isExpandable && focusAllowExpansion,
            keepAliveId: "focus",
            minimalText: isReminder ? "Focus Reminder • \(reminderDuration)" : "\(resolvedModeName) \(active ? "On" : "Off")",
            minimalIcon: displayIcon,
            systemTitle: resolvedModeName,
            systemSubtitle: isReminder ? "Focus Reminder • \(reminderDuration)" : (overlayState.isFocusSwitched ? "Switched" : (active ? "On" : "Off")),
            systemTertiaryText: nil,
            baseContent: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: displayIcon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(active ? displayColor : .secondary)
                        .frame(width: 26, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if active && overlayState.isFocusReminder {
                            HStack(spacing: 4) {
                                Text(displayTitle)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                Text("•")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: true, vertical: false)
                                if isPreview {
                                    Text("1:02:15")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                } else {
                                    let timerDate = details?.startDate ?? overlayState.focusActiveDate ?? Date().addingTimeInterval(-Double(mediaKeyManager.focusReminderInterval * 60))
                                    Text(timerDate, style: .timer)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                            }
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            MarqueeText(text: resolvedModeName, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                        } else if active && details != nil && !overlayState.isFocusReminder && !overlayState.isFocusSwitched {
                            if let endDate = details?.endDate, let timeStr = getEndDateString(date: endDate) {
                                HStack(spacing: 4) {
                                    Text(displayTitle)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                    Text("•")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: true, vertical: false)
                                    Text("until \(timeStr)")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                MarqueeText(text: resolvedModeName, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                            } else if details?.untilLocationLeft == true {
                                HStack(spacing: 4) {
                                    Text(displayTitle)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                    Text("•")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: true, vertical: false)
                                    Text("until I leave")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                MarqueeText(text: resolvedModeName, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                            } else {
                                Text(displayTitle)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                MarqueeText(text: resolvedModeName, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                            }
                        } else {
                            Text(displayTitle)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                            MarqueeText(text: resolvedModeName, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                        }
                    }
                    Spacer(minLength: 8)
                }
                .padding(.leading, 23)
                .padding(.trailing, 20)
            },
            expandedContent: {
                if active && overlayState.isFocusReminder {
                    let timerDate = details?.startDate ?? overlayState.focusActiveDate ?? Date().addingTimeInterval(-Double(mediaKeyManager.focusReminderInterval * 60))
                    VStack(alignment: .center, spacing: 2) {
                        Text("Active For")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        if isPreview {
                            Text("1:02:15")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        } else {
                            Text(timerDate, style: .timer)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                } else if active, let details = details {
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
                    .padding(.top, 8)
                    .padding(.bottom, 8)
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
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                    }
                } else {
                    EmptyView()
                }
            }
        )
    }
}
