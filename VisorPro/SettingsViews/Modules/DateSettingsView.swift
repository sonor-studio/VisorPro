import SwiftUI

struct DateSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("dateOverlayPosition") private var dateOverlayPosition: String = "top"
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("dateFormatOption") private var dateFormatOption: String = "EEE, d MMMM yyyy"
    @AppStorage("dateAllowExpansion") private var dateAllowExpansion: Bool = true
    
    @AppStorage("dateShowDayOfYear") private var showDayOfYear: Bool = true
    @AppStorage("dateShowWeekOfYear") private var showWeekOfYear: Bool = true
    @AppStorage("dateShowDaysLeft") private var showDaysLeft: Bool = true
    
    @AppStorage("dateCountdownTarget") private var countdownTarget: String = "None"
    @AppStorage("dateCustomCountdownDate") private var customCountdownDate: Double = Date().timeIntervalSince1970
    
    @AppStorage("dateShowCalendarEvents") private var showCalendarEvents: Bool = false
    @State private var showCalendarPermissionAlert = false
    
    private var moduleColor: Color {
        OverlayColorManager.shared.parseColor("Emerald")
    }
    
    var body: some View {
        ModuleSettingsLayout(
            title: "Date",
            isEnabled: $mediaKeyManager.enableDate,
            preview: {
                DateOverlayView(isPreview: true)
                    .applyTheme(mediaKeyManager.overlayTheme)
            },
            popovers: [
                ModulePopover(
                    icon: "calendar",
                    title: "Overlay Settings",
                    content: AnyView(
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "calendar", iconColor: moduleColor, title: "New Day", subtitle: "Show date and play sound when a new day begins") {
                                HStack(spacing: 8) {
                                    SoundPickerControl(selectedSound: $mediaKeyManager.soundOnDateChange)
                                    if mediaKeyManager.overlayColorMode == "custom" {
                                        ColorPickerControl(selectedColor: $mediaKeyManager.colorOnDateChange)
                                    }
                                }
                            }
                            
                            Divider().padding(.leading, 40)
                            
                            CustomSettingsRow(icon: "textformat", iconColor: moduleColor, title: "Date Format", subtitle: "Choose how the date is displayed") {
                                Picker("", selection: $dateFormatOption) {
                                    Text("Fri, 11 September 2026").tag("EEE, d MMMM yyyy")
                                    Text("Fri, 11 Sep 2026").tag("EEE, d MMM yyyy")
                                    Text("11 September 2026").tag("d MMMM yyyy")
                                    Text("Sep 11, 2026").tag("MMM d, yyyy")
                                    Text("11.09.2026").tag("dd.MM.yyyy")
                                    Text("11/09/2026").tag("dd/MM/yyyy")
                                    Text("09/11/2026").tag("MM/dd/yyyy")
                                    Text("2026-09-11").tag("yyyy-MM-dd")
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .frame(width: 180)
                            }
                        }
                    )
                ),
                ModulePopover(
                    icon: "list.bullet",
                    title: "Expanded Details",
                    content: AnyView(
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "number.circle", iconColor: moduleColor, title: "Day of Year", subtitle: "Show the current day out of 365/366") {
                                Toggle("", isOn: $showDayOfYear).toggleStyle(SwitchToggleStyle(tint: .accentColor)).labelsHidden()
                            }
                            Divider().padding(.leading, 40)
                            CustomSettingsRow(icon: "calendar.badge.clock", iconColor: moduleColor, title: "Week of Year", subtitle: "Show the current week number") {
                                Toggle("", isOn: $showWeekOfYear).toggleStyle(SwitchToggleStyle(tint: .accentColor)).labelsHidden()
                            }
                            Divider().padding(.leading, 40)
                            CustomSettingsRow(icon: "hourglass", iconColor: moduleColor, title: "Days Left", subtitle: "Show days remaining in the current year") {
                                Toggle("", isOn: $showDaysLeft).toggleStyle(SwitchToggleStyle(tint: .accentColor)).labelsHidden()
                            }
                            Divider().padding(.leading, 40)
                            CustomSettingsRow(icon: "timer", iconColor: moduleColor, title: "Countdown", subtitle: "Show days left until a specific date") {
                                 Picker("", selection: $countdownTarget) {
                                     Text("None").tag("None")
                                     Text("Christmas").tag("Christmas")
                                     Text("Easter").tag("Easter")
                                     Text("Halloween").tag("Halloween")
                                     Text("Valentine's Day").tag("Valentine's Day")
                                     Text("Start of Spring").tag("Spring Start")
                                     Text("Start of Summer").tag("Summer Start")
                                     Text("Start of Autumn").tag("Autumn Start")
                                     Text("Start of Winter").tag("Winter Start")
                                     Text("Custom Date").tag("Custom")
                                 }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .frame(width: 140)
                            }
                            if countdownTarget == "Custom" {
                                Divider().padding(.leading, 40)
                                CustomSettingsRow(icon: "calendar.badge.plus", iconColor: moduleColor, title: "Custom Date", subtitle: "Select your custom target date") {
                                    DatePicker("", selection: Binding(get: {
                                        Date(timeIntervalSince1970: customCountdownDate)
                                    }, set: { newDate in
                                        customCountdownDate = newDate.timeIntervalSince1970
                                    }), displayedComponents: .date)
                                    .labelsHidden()
                                    .frame(width: 140)
                                }
                            }
                            Divider().padding(.leading, 40)
                            CustomSettingsRow(icon: "calendar.day.timeline.left", iconColor: moduleColor, title: "Calendar Events", subtitle: "Show today's events from Calendar") {
                                Toggle("", isOn: $showCalendarEvents)
                                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                                    .labelsHidden()
                                    .onChange(of: showCalendarEvents) { _, newValue in
                                        if newValue {
                                            CalendarEventManager.shared.requestAccess { granted in
                                                if !granted {
                                                    showCalendarEvents = false
                                                    showCalendarPermissionAlert = true
                                                }
                                            }
                                        }
                                    }
                            }
                        }
                    )
                ),
                ModulePopover(
                    icon: "pip",
                    title: "Overlay Position",
                    show: overlayPositionMode == "custom",
                    content: AnyView(
                        Group {
                            if overlayPositionMode == "custom" {
                                PositionPickerGroup(selection: $dateOverlayPosition)
                                    .padding(.vertical, 8)
                            } else {
                                CustomSettingsRow(icon: "exclamationmark.triangle.fill", iconColor: .orange, title: "Custom Positioning Disabled", subtitle: "Enable Custom Positioning in General Settings to modify overlay placement.") {
                                    EmptyView()
                                }
                            }
                        }
                    )
                )
            ],
            inlineControls: [
                AnyView(
                    InlineControlView(
                        icon: "arrow.up.left.and.arrow.down.right",
                        title: "Allow Expansion",
                        control: Toggle("", isOn: $dateAllowExpansion)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    )
                )
            ]
        )
        .navigationTitle("Date")
        .alert("Calendar Access Required", isPresented: $showCalendarPermissionAlert) {
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("VisorPro needs access to your Calendar to display upcoming events. Please grant access in System Settings -> Privacy & Security -> Calendars.")
        }
        .onAppear {
            if dateFormatOption.contains("EEEE") {
                dateFormatOption = dateFormatOption.replacingOccurrences(of: "EEEE", with: "EEE")
            }
            if countdownTarget == "New Year" {
                countdownTarget = "Christmas"
            }
        }
    }
}
