import SwiftUI
import EventKit

struct DateOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @EnvironmentObject var overlayState: OverlayStateRelay
    @State private var isExpanded: Bool = false
    var isPreview: Bool = false
    @AppStorage("dateFormatOption") private var dateFormatOption: String = "EEEE, d MMMM yyyy"
    @AppStorage("dateShowDayOfYear") private var showDayOfYear: Bool = true
    @AppStorage("dateShowWeekOfYear") private var showWeekOfYear: Bool = true
    @AppStorage("dateShowDaysLeft") private var showDaysLeft: Bool = true
    @AppStorage("dateCountdownTarget") private var countdownTarget: String = "None"
    @AppStorage("dateCustomCountdownDate") private var customCountdownDate: Double = Date().timeIntervalSince1970
    @AppStorage("dateShowCalendarEvents") private var showCalendarEvents: Bool = false
    
    @ObservedObject private var calendarManager = CalendarEventManager.shared
    
    private var actionColor: Color {
        OverlayColorManager.shared.getOverlayColor(for: "colorOnDateChange", defaultColor: OverlayColorManager.shared.parseColor("Emerald"))
    }
    
    private func getEasterDate(year: Int) -> Date? {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1
        return Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
    }

    private func getCountdownDays() -> Int? {
        let cal = Calendar.current
        let baseDate = isPreview ? (cal.date(from: DateComponents(year: 2026, month: 9, day: 18)) ?? Date()) : Date()
        let today = cal.startOfDay(for: baseDate)
        var targetDate: Date?
        
        let currentYear = cal.component(.year, from: today)
        
        switch countdownTarget {
        case "Christmas":
            targetDate = cal.date(from: DateComponents(year: currentYear, month: 12, day: 25))
            if let t = targetDate, t < today {
                targetDate = cal.date(from: DateComponents(year: currentYear + 1, month: 12, day: 25))
            }
        case "Easter":
            targetDate = getEasterDate(year: currentYear)
            if let t = targetDate, t < today {
                targetDate = getEasterDate(year: currentYear + 1)
            }
        case "Halloween":
            targetDate = cal.date(from: DateComponents(year: currentYear, month: 10, day: 31))
            if let t = targetDate, t < today {
                targetDate = cal.date(from: DateComponents(year: currentYear + 1, month: 10, day: 31))
            }
        case "Valentine's Day":
            targetDate = cal.date(from: DateComponents(year: currentYear, month: 2, day: 14))
            if let t = targetDate, t < today {
                targetDate = cal.date(from: DateComponents(year: currentYear + 1, month: 2, day: 14))
            }
        case "Summer Start":
            targetDate = cal.date(from: DateComponents(year: currentYear, month: 6, day: 21))
            if let t = targetDate, t < today {
                targetDate = cal.date(from: DateComponents(year: currentYear + 1, month: 6, day: 21))
            }
        case "Autumn Start":
            targetDate = cal.date(from: DateComponents(year: currentYear, month: 9, day: 22))
            if let t = targetDate, t < today {
                targetDate = cal.date(from: DateComponents(year: currentYear + 1, month: 9, day: 22))
            }
        case "Winter Start":
            targetDate = cal.date(from: DateComponents(year: currentYear, month: 12, day: 21))
            if let t = targetDate, t < today {
                targetDate = cal.date(from: DateComponents(year: currentYear + 1, month: 12, day: 21))
            }
        case "Spring Start":
            targetDate = cal.date(from: DateComponents(year: currentYear, month: 3, day: 20))
            if let t = targetDate, t < today {
                targetDate = cal.date(from: DateComponents(year: currentYear + 1, month: 3, day: 20))
            }
        case "Custom":
            let custom = Date(timeIntervalSince1970: customCountdownDate)
            let month = cal.component(.month, from: custom)
            let day = cal.component(.day, from: custom)
            targetDate = cal.date(from: DateComponents(year: currentYear, month: month, day: day))
            if let t = targetDate, t < today {
                targetDate = cal.date(from: DateComponents(year: currentYear + 1, month: month, day: day))
            }
        default:
            return nil
        }
        
        if let target = targetDate {
            return cal.dateComponents([.day], from: today, to: target).day
        }
        return nil
    }

    private var formattedDate: String {
        let cal = Calendar.current
        let baseDate = isPreview ? (cal.date(from: DateComponents(year: 2026, month: 9, day: 18)) ?? Date()) : Date()
        let formatter = DateFormatter()
        let format = dateFormatOption.replacingOccurrences(of: "EEEE", with: "EEE")
        formatter.dateFormat = format
        return formatter.string(from: baseDate)
    }
    
    var body: some View {
        let datePos = MediaKeyManager.shared.getOverlayPosition(for: "dateOverlayPosition")
        
        return UniversalOverlayView(
            isPreview: isPreview,
            isExpanded: $isExpanded,
            showProgressBar: true,
            hasTimeoutProgress: true,
            timeoutEventId: overlayState.dateEventId,
            barColor: actionColor,
            fillCenter: false,
            isMuted: false,
            customWidth: 260,
            customHeight: 56,
            supportDragGesture: false,
            onSimpleTap: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    // No complex expansion for now
                }
            },
            isExpandable: true,
            expandUpwards: datePos.hasPrefix("bottom"),
            keepAliveId: "date",
            baseContent: {
                HStack(alignment: .center, spacing: 0) {
                    Image(systemName: "calendar")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 24)
                        .padding(.leading, 23)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("New Day")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Text(formattedDate)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.leading, 14)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            },
            expandedContent: {
                VStack(spacing: 8) {
                    if isPreview {
                        StatRow(icon: "number.circle", label: "Day of Year", value: "261", actionColor: actionColor)
                        StatRow(icon: "calendar.badge.clock", label: "Week of Year", value: "38", actionColor: actionColor)
                        StatRow(icon: "hourglass", label: "Days Left", value: "104", actionColor: actionColor)
                        StatRow(icon: "timer", label: "Days until Christmas", value: "98", actionColor: actionColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "calendar.day.timeline.left")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .frame(width: 16)
                                Text("Events Today")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("3")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            
                            MockEventRow(title: "Team Sync Meeting", color: .blue)
                            MockEventRow(title: "Design Review with Alex", color: .purple)
                            MockEventRow(title: "Project Pitch & Demo", color: .orange)
                        }
                    } else {
                        let cal = Calendar.current
                        let date = Date()
                        
                        if showDayOfYear {
                            let dayOfYear = cal.ordinality(of: .day, in: .year, for: date) ?? 1
                            StatRow(icon: "number.circle", label: "Day of Year", value: "\(dayOfYear)", actionColor: actionColor)
                        }
                        
                        if showWeekOfYear {
                            let weekOfYear = cal.component(.weekOfYear, from: date)
                            StatRow(icon: "calendar.badge.clock", label: "Week of Year", value: "\(weekOfYear)", actionColor: actionColor)
                        }
                        
                        if showDaysLeft {
                            let isLeap = cal.range(of: .day, in: .year, for: date)?.count == 366
                            let dayOfYear = cal.ordinality(of: .day, in: .year, for: date) ?? 1
                            let daysLeft = (isLeap ? 366 : 365) - dayOfYear
                            StatRow(icon: "hourglass", label: "Days Left", value: "\(daysLeft)", actionColor: actionColor)
                        }
                        
                        if countdownTarget != "None", let days = getCountdownDays() {
                            let targetLabel = countdownTarget == "Custom" ? "Target Date" : countdownTarget
                            let valueStr = days == 0 ? "Today" : "\(days)"
                            StatRow(icon: "timer", label: "Days until \(targetLabel)", value: valueStr, actionColor: actionColor)
                        }
                        
                        if showCalendarEvents {
                            if !calendarManager.hasAccess {
                                StatRow(icon: "calendar.day.timeline.left", label: "Events Today", value: "No Access", actionColor: actionColor)
                            } else if calendarManager.todaysEvents.isEmpty {
                                StatRow(icon: "calendar.day.timeline.left", label: "Events Today", value: "None", actionColor: actionColor)
                            } else {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "calendar.day.timeline.left")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.secondary)
                                            .frame(width: 16)
                                        Text("Events Today")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(calendarManager.todaysEvents.count)")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundColor(.primary)
                                    }
                                    
                                    let eventsToDisplay = calendarManager.todaysEvents
                                    
                                    if eventsToDisplay.count > 4 {
                                        ScrollView(.vertical, showsIndicators: false) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                ForEach(eventsToDisplay, id: \.eventIdentifier) { event in
                                                    EventRow(event: event, actionColor: actionColor)
                                                }
                                            }
                                        }
                                        .frame(height: 80) // ok. 4 elementy (16-18px każdy + spacing 4)
                                        .onHover { hovering in
                                            DispatchQueue.main.async {
                                                if OverlayStateRelay.shared.isHoveringScrollView != hovering {
                                                    OverlayStateRelay.shared.isHoveringScrollView = hovering
                                                }
                                            }
                                        }
                                    } else {
                                        VStack(alignment: .leading, spacing: 4) {
                                            ForEach(eventsToDisplay, id: \.eventIdentifier) { event in
                                                EventRow(event: event, actionColor: actionColor)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .onAppear {
                    if showCalendarEvents && !isPreview {
                        calendarManager.fetchTodaysEvents()
                    }
                }
            }
        )
    }
}

struct EventRow: View {
    let event: EKEvent
    let actionColor: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(event.calendar?.cgColor != nil ? Color(nsColor: NSColor(cgColor: event.calendar.cgColor)!) : actionColor)
                .frame(width: 6, height: 6)
            Text(event.title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.leading, 22)
    }
}

struct MockEventRow: View {
    let title: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.leading, 22)
    }
}
