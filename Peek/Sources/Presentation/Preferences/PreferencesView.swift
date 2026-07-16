import SwiftUI
import EventKit
import Foundation

struct PreferencesView: View {
    @ObservedObject var calendarManager: CalendarManager
    @Environment(\.dismiss) var dismiss
    @State private var launchAtLogin: Bool
    @State private var selectedTab = 0
    @State private var importExportFeedback: (message: String, isError: Bool)?
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
        .frame(width: 500, height: 700)
        .fixedSize()
        .background(PeekColor.canvas)
        .preferredColorScheme(preferredColorScheme)
    }

    private var tabBar: some View {
        HStack(spacing: 22) {
            TabButton(title: NSLocalizedString("Calendars", comment: "Preferences tab title"), isSelected: selectedTab == 0) { selectedTab = 0 }
            TabButton(title: NSLocalizedString("Filters", comment: "Preferences tab title"), isSelected: selectedTab == 1) { selectedTab = 1 }
            TabButton(title: NSLocalizedString("General", comment: "Preferences tab title"), isSelected: selectedTab == 2) { selectedTab = 2 }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .background(PeekColor.surface)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            if let feedback = importExportFeedback {
                HStack(spacing: 5) {
                    Image(systemName: feedback.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .accessibilityHidden(true)
                    Text(feedback.message)
                        .font(PeekFont.caption)
                }
                .foregroundColor(feedback.isError ? PeekColor.critical : PeekColor.calm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            HStack(spacing: 10) {
                Button(NSLocalizedString("Export…", comment: "Export settings button")) { exportSettings() }
                    .buttonStyle(.bordered)
                    .accessibilityHint(NSLocalizedString("Saves Peek settings to a JSON file", comment: "Accessibility hint for Export Settings button"))

                Button(NSLocalizedString("Import…", comment: "Import settings button")) { importSettings() }
                    .buttonStyle(.bordered)
                    .accessibilityHint(NSLocalizedString("Loads Peek settings from a JSON file", comment: "Accessibility hint for Import Settings button"))

                Spacer()

                Text(AppVersion.from().displayText)
                    .font(PeekFont.caption)
                    .foregroundColor(PeekColor.tertiaryText)
                    .accessibilityLabel(AppVersion.from().displayText)

                Button(NSLocalizedString("Done", comment: "Done button")) {
                    calendarManager.savePreferences()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .background(PeekColor.surface)
    }

    private func exportSettings() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = NSLocalizedString("PeekSettings.json", comment: "Default export file name")
        savePanel.title = NSLocalizedString("Export Peek Settings", comment: "Export settings panel title")

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                let settings = calendarManager.exportSettings()
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
                    try jsonData.write(to: url)
                    self.importExportFeedback = (
                        NSLocalizedString("Settings exported successfully.", comment: "Export settings success message"),
                        false
                    )
                } catch {
                    self.importExportFeedback = (
                        String(format: NSLocalizedString("Export failed: %@", comment: "Export settings error message format"), error.localizedDescription),
                        true
                    )
                }
            }
        }
    }

    private func importSettings() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.title = NSLocalizedString("Import Peek Settings", comment: "Import settings panel title")

        openPanel.begin { response in
            if response == .OK, let url = openPanel.urls.first {
                do {
                    let jsonData = try Data(contentsOf: url)
                    if let settings = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                        let result = self.calendarManager.importSettings(settings)
                        switch result {
                        case .success:
                            self.importExportFeedback = (
                                NSLocalizedString("Settings imported successfully.", comment: "Import settings success message"),
                                false
                            )
                        case .failure(.incompatibleVersion):
                            self.importExportFeedback = (
                                NSLocalizedString("Import failed: settings file is incompatible.", comment: "Import settings incompatible version error message"),
                                true
                            )
                        }
                    } else {
                        self.importExportFeedback = (
                            NSLocalizedString("Import failed: invalid settings file.", comment: "Import settings invalid file error message"),
                            true
                        )
                    }
                } catch {
                    self.importExportFeedback = (
                        String(format: NSLocalizedString("Import failed: %@", comment: "Import settings error message format"), error.localizedDescription),
                        true
                    )
                }
            }
        }
    }
}

// MARK: - Calendars Tab

struct CalendarsTab: View {
    @ObservedObject var calendarManager: CalendarManager
    let availableCalendars: [EKCalendar]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("Calendars to monitor", comment: "Calendars tab heading"))
                    .font(Font.system(size: 15, weight: .semibold))
                    .foregroundColor(PeekColor.ink)
                Text(NSLocalizedString("Choose which calendars appear in the menu bar.", comment: "Calendars tab subtitle"))
                    .font(PeekFont.bodyMeta)
                    .foregroundColor(PeekColor.secondaryText)

                if !calendarManager.hasCalendarAccess {
                    InsetCard {
                        Text(NSLocalizedString("Calendar access not granted", comment: "No calendar access"))
                            .font(PeekFont.bodyMeta)
                            .foregroundColor(PeekColor.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(24)
                    }
                } else if availableCalendars.isEmpty {
                    InsetCard {
                        Text(NSLocalizedString("No calendars found", comment: "No calendars"))
                            .font(PeekFont.bodyMeta)
                            .foregroundColor(PeekColor.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(24)
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

                    HStack(spacing: 8) {
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
            .padding(20)
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
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("Event filters", comment: "Filters tab heading"))
                    .font(Font.system(size: 15, weight: .semibold))
                    .foregroundColor(PeekColor.ink)
                Text(NSLocalizedString("Control which events are displayed.", comment: "Filters tab subtitle"))
                    .font(PeekFont.bodyMeta)
                    .foregroundColor(PeekColor.secondaryText)
                    .padding(.bottom, 8)

                InsetCard {
                    SettingRow(NSLocalizedString("Hide all-day events", comment: "Filter toggle")) {
                        switchToggle($calendarManager.hideAllDayEvents)
                    }
                    RowDivider()
                    SettingRow(NSLocalizedString("Hide declined events", comment: "Filter toggle")) {
                        switchToggle($calendarManager.hideDeclinedEvents)
                    }
                }

                GroupLabel(NSLocalizedString("Keyword filter", comment: "Keyword filter group label"))
                    .padding(.top, 16)
                InsetCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(NSLocalizedString("Hide events whose title or notes contain these words (comma-separated).", comment: "Keyword filter description"))
                            .font(PeekFont.caption)
                            .foregroundColor(PeekColor.secondaryText)
                        KeywordChipEditor(text: $calendarManager.filterKeywords)
                    }
                    .padding(14)
                }

                Spacer()
            }
            .padding(20)
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
        VStack(alignment: .leading, spacing: 8) {
            if !keywords.isEmpty {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 84), spacing: 6, alignment: .leading)],
                    alignment: .leading,
                    spacing: 6
                ) {
                    ForEach(keywords, id: \.self) { keyword in
                        PeekKeywordChip(title: keyword) {
                            remove(keyword)
                        }
                    }
                }
            }

            HStack(spacing: 6) {
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
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? PeekColor.tertiaryText : PeekColor.accent)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help(NSLocalizedString("Add keyword", comment: "Keyword chip add help"))
                .accessibilityLabel(Text(NSLocalizedString("Add keyword", comment: "Keyword chip add accessibility label")))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(PeekColor.fill)
            .clipShape(RoundedRectangle(cornerRadius: PeekRadius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PeekRadius.button, style: .continuous)
                    .strokeBorder(PeekColor.innerDivider, lineWidth: 1)
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
            VStack(alignment: .leading, spacing: 16) {
                // Launch at login (ungrouped card)
                InsetCard {
                    SettingRow(NSLocalizedString("Launch at login", comment: "Launch at login toggle")) {
                        switchToggle(launchAtLoginBinding)
                    }
                }
                if let launchAtLoginErrorMessage {
                    Text(launchAtLoginErrorMessage)
                        .font(PeekFont.caption)
                        .foregroundColor(PeekColor.critical)
                        .padding(.horizontal, 4)
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
                        .frame(width: 150)
                        .accessibilityLabel(NSLocalizedString("Look ahead", comment: "Accessibility label for look ahead picker"))
                    }
                    RowDivider()
                    SettingRow(NSLocalizedString("Max events to show", comment: "Max events setting")) {
                        Picker("", selection: $calendarManager.maxEventsToShow) {
                            ForEach([3, 5, 10, 15, 20], id: \.self) { Text("\($0)").tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 90)
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
                        .frame(width: 200)
                        .accessibilityLabel(NSLocalizedString("Time format", comment: "Accessibility label for time format"))
                    }
                    RowDivider()
                    SettingRow(NSLocalizedString("Space policy", comment: "Space policy setting")) {
                        Picker("", selection: $calendarManager.menuBarSpacePolicy) {
                            ForEach(MenuBarSpacePolicy.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 180)
                        .accessibilityLabel(NSLocalizedString("Space policy", comment: "Accessibility label for space policy"))
                    }
                    RowDivider()
                    SettingRow(NSLocalizedString("Show event count badge", comment: "Show count toggle")) {
                        switchToggle($calendarManager.showEventCount)
                    }
                    RowDivider()
                    SettingRow(
                        NSLocalizedString("Use urgency colors", comment: "Urgency colors toggle"),
                        subtitle: NSLocalizedString("Tint the title amber, then red, as time runs out.", comment: "Urgency colors subtitle")
                    ) {
                        switchToggle($calendarManager.urgencyColorsEnabled)
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
                        .frame(width: 200)
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
                        .frame(width: 110)
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
                        switchToggle($calendarManager.notificationsEnabled)
                    }
                    if calendarManager.notificationsEnabled {
                        RowDivider()
                        SettingRow(NSLocalizedString("Alert timing", comment: "Alert timing setting")) {
                            Picker("", selection: $calendarManager.notificationTiming) {
                                ForEach(NotificationTiming.allCases, id: \.self) { Text($0.displayName).tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: 150)
                            .accessibilityLabel(NSLocalizedString("Alert timing", comment: "Accessibility label for alert timing"))
                        }
                    }
                }
            }
            .padding(20)
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
        Text(text)
            .font(PeekFont.caption)
            .foregroundColor(isError ? PeekColor.critical : PeekColor.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
    }
}

// MARK: - Shared trailing switch

@ViewBuilder
func switchToggle(_ isOn: Binding<Bool>) -> some View {
    Toggle("", isOn: isOn)
        .labelsHidden()
        .toggleStyle(.switch)
        .tint(PeekColor.accent)
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title)
                    .font(Font.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? PeekColor.ink : PeekColor.secondaryText)
                Rectangle()
                    .fill(isSelected ? PeekColor.accent : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
    }
}
