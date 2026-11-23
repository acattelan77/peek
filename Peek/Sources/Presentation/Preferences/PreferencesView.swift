import SwiftUI
import EventKit
import Foundation

struct PreferencesView: View {
    @ObservedObject var calendarManager: CalendarManager
    @Environment(\.dismiss) var dismiss
    @State private var launchAtLogin: Bool
    @State private var selectedTab = 0
    private let launchAtLoginController: any LaunchAtLoginControlling

    init(
        calendarManager: CalendarManager,
        launchAtLoginController: any LaunchAtLoginControlling = SystemLaunchAtLoginController()
    ) {
        self.calendarManager = calendarManager
        self.launchAtLoginController = launchAtLoginController
        _launchAtLogin = State(initialValue: launchAtLoginController.currentValue)
    }

    private var availableCalendars: [EKCalendar] {
        calendarManager.getAllCalendars().sorted { $0.title < $1.title }
    }

    private var preferredColorScheme: ColorScheme? {
        switch calendarManager.appearanceMode {
        case .auto: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider().overlay(PeekColor.hairline)

            Group {
                if selectedTab == 0 {
                    CalendarsTab(calendarManager: calendarManager, availableCalendars: availableCalendars)
                } else if selectedTab == 1 {
                    FiltersTab(calendarManager: calendarManager)
                } else {
                    GeneralTab(
                        calendarManager: calendarManager,
                        launchAtLogin: $launchAtLogin,
                        launchAtLoginController: launchAtLoginController
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().overlay(PeekColor.hairline)
            footer
        }
        .frame(width: PeekMetrics.preferencesSize.width, height: PeekMetrics.preferencesSize.height)
        .fixedSize()
        .background(PeekColor.canvas)
        .preferredColorScheme(preferredColorScheme)
    }

    private var tabBar: some View {
        HStack(spacing: PeekMetrics.tabGap) {
            PeekTabButton(title: NSLocalizedString("Calendars", comment: "Preferences tab title"), isSelected: selectedTab == 0) { selectedTab = 0 }
            PeekTabButton(title: NSLocalizedString("Filters", comment: "Preferences tab title"), isSelected: selectedTab == 1) { selectedTab = 1 }
            PeekTabButton(title: NSLocalizedString("General", comment: "Preferences tab title"), isSelected: selectedTab == 2) { selectedTab = 2 }
            Spacer()
        }
        .padding(.horizontal, PeekSpacing.lg)
        .padding(.top, PeekSpacing.lg)
        .background(PeekColor.surface)
    }

    private var footer: some View {
        HStack(spacing: PeekMetrics.headerGap) {
            Text(AppVersion.from().displayText)
                .font(PeekFont.caption)
                .foregroundColor(PeekColor.tertiaryText)
                .accessibilityLabel(AppVersion.from().displayText)

            Spacer()

            Button(NSLocalizedString("Done", comment: "Done button")) {
                calendarManager.savePreferences()
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(PeekSpacing.lg)
        .background(PeekColor.surface)
    }
}

// MARK: - Calendars Tab

struct CalendarsTab: View {
    @ObservedObject var calendarManager: CalendarManager
    let availableCalendars: [EKCalendar]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PeekSpacing.sm) {
                PeekSectionHeader(
                    title: NSLocalizedString("Calendars to monitor", comment: "Calendars tab heading"),
                    subtitle: NSLocalizedString("Choose which calendars appear in the menu bar.", comment: "Calendars tab subtitle")
                )

                if !calendarManager.hasCalendarAccess {
                    InsetCard {
                        InsetCardMessage(text: NSLocalizedString("Calendar access not granted", comment: "No calendar access"))
                    }
                } else if availableCalendars.isEmpty {
                    InsetCard {
                        InsetCardMessage(text: NSLocalizedString("No calendars found", comment: "No calendars"))
                    }
                } else {
                    InsetCard {
                        ForEach(Array(availableCalendars.enumerated()), id: \.element.calendarIdentifier) { index, calendar in
                            CalendarRow(
                                calendar: calendar,
                                isEnabled: calendarManager.isCalendarEnabled(calendar.calendarIdentifier)
                            ) {
                                calendarManager.toggleCalendar(calendar.calendarIdentifier)
                            }
                            if index < availableCalendars.count - 1 { RowDivider() }
                        }
                    }

                    HStack(spacing: PeekSpacing.sm) {
                        Button(NSLocalizedString("Select all", comment: "Select all calendars")) {
                            for calendar in availableCalendars where !calendarManager.isCalendarEnabled(calendar.calendarIdentifier) {
                                calendarManager.toggleCalendar(calendar.calendarIdentifier)
                            }
                        }
                        .buttonStyle(SoftAccentButtonStyle())

                        Button(NSLocalizedString("Deselect all", comment: "Deselect all calendars")) {
                            for calendar in availableCalendars where calendarManager.isCalendarEnabled(calendar.calendarIdentifier) {
                                calendarManager.toggleCalendar(calendar.calendarIdentifier)
                            }
                        }
                        .buttonStyle(SecondaryFillButtonStyle())

                        Spacer()
                    }
                }
            }
            .padding(PeekSpacing.xl)
        }
    }
}

private struct CalendarRow: View {
    let calendar: EKCalendar
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        PeekCheckboxRow(
            label: calendar.title,
            color: Color(calendar.color),
            isOn: isEnabled,
            onToggle: onToggle
        ) {
            Text(calendarTypeDescription(calendar.type))
                .font(PeekFont.caption)
                .foregroundColor(PeekColor.tertiaryText)
        }
    }

    private func calendarTypeDescription(_ type: EKCalendarType) -> String {
        switch type {
        case .local: return NSLocalizedString("Local", comment: "Calendar type: local")
        case .calDAV: return NSLocalizedString("iCloud", comment: "Calendar type: CalDAV")
        case .exchange: return NSLocalizedString("Exchange", comment: "Calendar type: Exchange")
        case .subscription: return NSLocalizedString("Subscription", comment: "Calendar type: subscription")
        case .birthday: return NSLocalizedString("Birthday", comment: "Calendar type: birthday")
        @unknown default: return ""
        }
    }
}

// MARK: - Filters Tab

struct FiltersTab: View {
    @ObservedObject var calendarManager: CalendarManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PeekSpacing.sm) {
                PeekSectionHeader(
                    title: NSLocalizedString("Event filters", comment: "Filters tab heading"),
                    subtitle: NSLocalizedString("Control which events are displayed.", comment: "Filters tab subtitle")
                )
                .padding(.bottom, PeekSpacing.sm)

                InsetCard {
                    SettingRow(NSLocalizedString("Hide all-day events", comment: "Filter toggle")) {
                        switchToggle($calendarManager.hideAllDayEvents, label: NSLocalizedString("Hide all-day events", comment: "Filter toggle"))
                    }
                    RowDivider()
                    SettingRow(NSLocalizedString("Hide declined events", comment: "Filter toggle")) {
                        switchToggle($calendarManager.hideDeclinedEvents, label: NSLocalizedString("Hide declined events", comment: "Filter toggle"))
                    }
                }

                GroupLabel(NSLocalizedString("Keyword filter", comment: "Keyword filter group label"))
                    .padding(.top, PeekSpacing.lg)
                InsetCard {
                    VStack(alignment: .leading, spacing: PeekMetrics.headerGap) {
                        Text(NSLocalizedString("Hide events whose title or notes contain these words (comma-separated).", comment: "Keyword filter description"))
                            .font(PeekFont.caption)
                            .foregroundColor(PeekColor.secondaryText)
                        KeywordChipEditor(text: $calendarManager.filterKeywords)
                    }
                    .padding(PeekMetrics.cardContentPadding)
                }

                Spacer()
            }
            .padding(PeekSpacing.xl)
        }
    }
}

private struct KeywordChipEditor: View {
    @Binding var text: String
    @State private var draft = ""

    private var keywords: [String] {
        parse(text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PeekSpacing.sm) {
            if !keywords.isEmpty {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: PeekMetrics.chipMinWidth), spacing: PeekSpacing.iconGap, alignment: .leading)],
                    alignment: .leading,
                    spacing: PeekSpacing.iconGap
                ) {
                    ForEach(keywords, id: \.self) { keyword in
                        PeekKeywordChip(title: keyword) {
                            remove(keyword)
                        }
                    }
                }
            }

            HStack(spacing: PeekSpacing.iconGap) {
                TextField(
                    NSLocalizedString("Add keyword…", comment: "Keyword chip input placeholder"),
                    text: $draft
                )
                .textFieldStyle(.plain)
                .font(PeekFont.bodyMeta)
                .foregroundColor(PeekColor.ink)
                .onSubmit(addDraftKeywords)
                .onChange(of: draft) { newValue in
                    guard newValue.contains(",") else { return }
                    addDraftKeywords()
                }
                Button(action: addDraftKeywords) {
                    Image(systemName: "plus.circle.fill")
                        .font(PeekIcon.inlineAction)
                        .foregroundColor(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? PeekColor.tertiaryText : PeekColor.accentText)
                        .frame(width: PeekMetrics.toolbarButton, height: PeekMetrics.toolbarButton)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help(NSLocalizedString("Add keyword", comment: "Keyword chip add help"))
                .accessibilityLabel(Text(NSLocalizedString("Add keyword", comment: "Keyword chip add accessibility label")))
            }
            .padding(PeekMetrics.inputInsets)
            .background(PeekColor.fill)
            .clipShape(RoundedRectangle(cornerRadius: PeekRadius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PeekRadius.button, style: .continuous)
                    .strokeBorder(PeekColor.controlStroke, lineWidth: PeekSpacing.hairline)
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(NSLocalizedString("Keyword filter", comment: "Keyword chip editor accessibility label")))
    }

    private func addDraftKeywords() {
        let newKeywords = parse(draft)
        guard !newKeywords.isEmpty else {
            draft = ""
            return
        }
        let merged = keywords + newKeywords
        text = normalized(merged)
        draft = ""
    }

    private func remove(_ keyword: String) {
        text = normalized(keywords.filter { $0 != keyword })
    }

    private func parse(_ value: String) -> [String] {
        value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func normalized(_ values: [String]) -> String {
        var seen = Set<String>()
        let unique = values.filter { value in
            let key = value.lowercased()
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
        return unique.joined(separator: ", ")
    }
}

// MARK: - General Tab

struct GeneralTab: View {
    @ObservedObject var calendarManager: CalendarManager
    @Binding var launchAtLogin: Bool
    let launchAtLoginController: any LaunchAtLoginControlling
    @State private var launchAtLoginErrorMessage: String?

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { newValue in
                let result = LaunchAtLoginCoordinator.apply(
                    requestedValue: newValue,
                    controller: launchAtLoginController
                )
                launchAtLogin = result.effectiveValue
                UserDefaults.standard.set(result.effectiveValue, forKey: "launchAtLogin")
                launchAtLoginErrorMessage = result.errorMessage
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PeekSpacing.lg) {
                // Launch at login (ungrouped card)
                InsetCard {
                    SettingRow(NSLocalizedString("Launch at login", comment: "Launch at login toggle")) {
                        switchToggle(launchAtLoginBinding, label: NSLocalizedString("Launch at login", comment: "Launch at login toggle"))
                    }
                }
                if let launchAtLoginErrorMessage {
                    Text(launchAtLoginErrorMessage)
                        .font(PeekFont.caption)
                        .foregroundColor(PeekColor.criticalText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, PeekSpacing.xs)
                }

                // Schedule
                settingsGroup(NSLocalizedString("Schedule", comment: "Group label: schedule")) {
                    SettingRow(NSLocalizedString("Look ahead", comment: "Look ahead setting")) {
                        Picker("", selection: $calendarManager.lookaheadDays) {
                            Text(NSLocalizedString("Today only", comment: "")).tag(1)
                            Text(NSLocalizedString("Next 3 days", comment: "")).tag(3)
                            Text(NSLocalizedString("Next 7 days", comment: "")).tag(7)
                            Text(NSLocalizedString("Next 14 days", comment: "")).tag(14)
                            Text(NSLocalizedString("Next 30 days", comment: "")).tag(30)
                        }
                        .labelsHidden()
                        .frame(width: PeekMetrics.pickerMedium)
                        .accessibilityLabel(NSLocalizedString("Look ahead", comment: "Accessibility label for look ahead picker"))
                    }
                    RowDivider()
                    SettingRow(NSLocalizedString("Max events to show", comment: "Max events setting")) {
                        Picker("", selection: $calendarManager.maxEventsToShow) {
                            ForEach([3, 5, 10, 15, 20], id: \.self) { Text("\($0)").tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: PeekMetrics.pickerCompact)
                        .accessibilityLabel(NSLocalizedString("Max events to show", comment: "Accessibility label for max events picker"))
                    }
                }

                // Status bar display
                settingsGroup(NSLocalizedString("Status bar display", comment: "Group label: status bar")) {
                    SettingRow(NSLocalizedString("Time format", comment: "Time format setting")) {
                        Picker("", selection: $calendarManager.statusBarMode) {
                            ForEach(StatusBarDisplayMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: PeekMetrics.pickerSegmented)
                        .accessibilityLabel(NSLocalizedString("Time format", comment: "Accessibility label for time format"))
                    }
                    RowDivider()
                    SettingRow(NSLocalizedString("Space policy", comment: "Space policy setting")) {
                        Picker("", selection: $calendarManager.menuBarSpacePolicy) {
                            ForEach(MenuBarSpacePolicy.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: PeekMetrics.pickerWide)
                        .accessibilityLabel(NSLocalizedString("Space policy", comment: "Accessibility label for space policy"))
                    }
                    RowDivider()
                    SettingRow(NSLocalizedString("Show event count badge", comment: "Show count toggle")) {
                        switchToggle($calendarManager.showEventCount, label: NSLocalizedString("Show event count badge", comment: "Show count toggle"))
                    }
                    RowDivider()
                    SettingRow(
                        NSLocalizedString("Use urgency colors", comment: "Urgency colors toggle"),
                        subtitle: NSLocalizedString("Tint the title amber, then red, as time runs out.", comment: "Urgency colors subtitle")
                    ) {
                        switchToggle($calendarManager.urgencyColorsEnabled, label: NSLocalizedString("Use urgency colors", comment: "Urgency colors toggle"))
                    }
                }

                // Appearance
                settingsGroup(NSLocalizedString("Appearance", comment: "Group label: appearance")) {
                    SettingRow(NSLocalizedString("Theme", comment: "Theme setting")) {
                        Picker("", selection: $calendarManager.appearanceMode) {
                            ForEach(AppearanceMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: PeekMetrics.pickerSegmented)
                        .accessibilityLabel(NSLocalizedString("Theme", comment: "Accessibility label for theme"))
                    }
                }

                // Shortcut & alerts
                settingsGroup(NSLocalizedString("Shortcut & alerts", comment: "Group label: shortcut and alerts")) {
                    SettingRow(NSLocalizedString("Global hotkey", comment: "Global hotkey setting")) {
                        Picker("", selection: $calendarManager.globalHotkey) {
                            ForEach(HotkeyOption.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: PeekMetrics.pickerHotkey)
                        .accessibilityLabel(NSLocalizedString("Global hotkey", comment: "Accessibility label for global hotkey"))
                    }
                    if let hotkeyStatusMessage = calendarManager.hotkeyStatusMessage {
                        rowFootnote(hotkeyStatusMessage, isError: true)
                    }
                    RowDivider()
                    SettingRow(
                        NSLocalizedString("Meeting notifications", comment: "Notifications toggle"),
                        subtitle: NSLocalizedString("Alert with a join link before an event starts.", comment: "Notifications subtitle")
                    ) {
                        switchToggle($calendarManager.notificationsEnabled, label: NSLocalizedString("Meeting notifications", comment: "Notifications toggle"))
                    }
                    if let notificationStatusMessage = calendarManager.notificationStatusMessage {
                        rowFootnote(notificationStatusMessage, isError: true)
                    }
                    if calendarManager.notificationsEnabled {
                        RowDivider()
                        SettingRow(NSLocalizedString("Alert timing", comment: "Alert timing setting")) {
                            Picker("", selection: $calendarManager.notificationTiming) {
                                ForEach(NotificationTiming.allCases, id: \.self) { Text($0.displayName).tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: PeekMetrics.pickerMedium)
                            .accessibilityLabel(NSLocalizedString("Alert timing", comment: "Accessibility label for alert timing"))
                        }
                    }
                    RowDivider()
                    SettingRow(
                        NSLocalizedString("Open meetings in the app", comment: "Native meeting app toggle"),
                        subtitle: NSLocalizedString("Use Zoom or Teams when installed, otherwise the browser.", comment: "Native meeting app subtitle")
                    ) {
                        switchToggle($calendarManager.openMeetingsInNativeApp, label: NSLocalizedString("Open meetings in the app", comment: "Native meeting app toggle"))
                    }
                }
            }
            .padding(PeekSpacing.xl)
        }
    }

    @ViewBuilder
    private func settingsGroup<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            GroupLabel(label)
            InsetCard { content() }
        }
    }

    private func rowFootnote(_ text: String, isError: Bool) -> some View {
        SettingFootnote(text: text, isError: isError)
    }
}

// MARK: - Shared trailing switch

func switchToggle(_ isOn: Binding<Bool>, label: String) -> some View {
    PeekSwitch(isOn: isOn, accessibilityLabel: label)
}
