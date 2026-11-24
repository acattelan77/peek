import SwiftUI
import AppKit
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
                switch selectedTab {
                case 0: generalTab(.meetings)
                case 1: generalTab(.prepared)
                case 2:
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: PeekSpacing.xxl) {
                            CalendarsTab(calendarManager: calendarManager, availableCalendars: availableCalendars).content
                            FiltersTab(calendarManager: calendarManager).content
                        }
                        .padding(PeekSpacing.xl)
                    }
                default: generalTab(.general)
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
            PeekTabButton(title: NSLocalizedString("Alerts", comment: "Preferences tab title: alerts, joining and the menu bar"), isSelected: selectedTab == 0) { selectedTab = 0 }
            PeekTabButton(title: NSLocalizedString("Briefs", comment: "Preferences tab title: meeting context and briefs"), isSelected: selectedTab == 1) { selectedTab = 1 }
            PeekTabButton(title: NSLocalizedString("Calendars", comment: "Preferences tab title"), isSelected: selectedTab == 2) { selectedTab = 2 }
            PeekTabButton(title: NSLocalizedString("General", comment: "Preferences tab title"), isSelected: selectedTab == 3) { selectedTab = 3 }
            Spacer()
        }
        .padding(.horizontal, PeekSpacing.lg)
        .padding(.top, PeekSpacing.lg)
        .background(PeekColor.surface)
    }

    private func generalTab(_ section: GeneralTab.Section) -> some View {
        GeneralTab(
            calendarManager: calendarManager,
            section: section,
            launchAtLogin: $launchAtLogin,
            launchAtLoginController: launchAtLoginController
        )
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
        ScrollView(showsIndicators: false) {
            content
                .padding(PeekSpacing.xl)
        }
    }

    var content: some View {
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
        ScrollView(showsIndicators: false) {
            content
                .padding(PeekSpacing.xl)
        }
    }

    var content: some View {
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

/// The settings grouped by purpose (Peek 2.0): never miss a meeting, arrive
/// prepared, and general. One view keeps the shared state and bindings.
struct GeneralTab: View {
    enum Section { case meetings, prepared, general }

    @ObservedObject var calendarManager: CalendarManager
    var section: Section = .general
    @Binding var launchAtLogin: Bool
    let launchAtLoginController: any LaunchAtLoginControlling
    @State private var launchAtLoginErrorMessage: String?
    @ObservedObject private var briefService = MeetingBriefService.shared
    @State private var apiKeyDraft = ""
    @State private var apiKeyMessage: String?
    @State private var diagnosticsMessage: String?
    @State private var diagnosticsFailed = false
    @State private var hasAPIKey = AnthropicKeyStore.hasKey

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
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: PeekSpacing.lg) {
                if section == .meetings {
                    // Peek 2.0 Preferences mockup: the alert ladder, which
                    // meetings interrupt, joining, and what the menu bar shows.
                    settingsGroup(NSLocalizedString("Alerts", comment: "Group label: the alert ladder")) {
                        ladderRow(hint: NSLocalizedString("A quiet notification", comment: "Alert ladder: hint for the notification ahead of time")) {
                            Menu {
                                ForEach(NotificationTiming.allCases.filter { $0 != .none }, id: \.self) { timing in
                                    Button(timing.displayName) { calendarManager.notificationTiming = timing }
                                }
                            } label: {
                                Text(leadTime.displayName)
                                    .font(PeekFont.rowTitle)
                                    .foregroundColor(PeekColor.ink)
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                            .accessibilityLabel(NSLocalizedString("Alert timing", comment: "Accessibility label for alert timing"))
                        } level: {
                            levelPicker(beforeLevelBinding, options: AlertLevel.beforeOptions, label: leadTime.displayName)
                        }
                        if let notificationStatusMessage = calendarManager.notificationStatusMessage {
                            rowFootnote(notificationStatusMessage, isError: true)
                        }
                        RowDivider()
                        ladderRow(hint: NSLocalizedString("Red menu bar and a card at the top", comment: "Alert ladder: hint 2 minutes before")) {
                            ladderTitle(NSLocalizedString("2 minutes before", comment: "Alert ladder: the step 2 minutes before a meeting"))
                        } level: {
                            levelPicker(soonLevelBinding, options: AlertLevel.soonOptions, label: NSLocalizedString("2 minutes before", comment: "Alert ladder: the step 2 minutes before a meeting"))
                        }
                        RowDivider()
                        ladderRow(hint: NSLocalizedString("Interrupts until you choose", comment: "Alert ladder: hint at the start")) {
                            ladderTitle(NSLocalizedString("At the start", comment: "Alert ladder: the step when a meeting starts"))
                        } level: {
                            levelPicker(startLevelBinding, options: AlertLevel.startOptions, label: NSLocalizedString("At the start", comment: "Alert ladder: the step when a meeting starts"))
                        }
                    }

                    settingsGroup(NSLocalizedString("Which meetings", comment: "Group label: which meetings interrupt")) {
                        VStack(alignment: .leading, spacing: 0) {
                            PeekCheckboxRow(
                                label: NSLocalizedString("Interrupt only for meetings with a link or attendees", comment: "Which meetings: interrupt only for real meetings"),
                                isOn: calendarManager.interruptOnlyForMeetings,
                                onToggle: { calendarManager.interruptOnlyForMeetings.toggle() }
                            )
                            if !alertCalendars.isEmpty {
                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: PeekMetrics.chipMinWidth), spacing: PeekSpacing.iconGap, alignment: .leading)],
                                    alignment: .leading,
                                    spacing: PeekSpacing.iconGap
                                ) {
                                    ForEach(alertCalendars, id: \.calendarIdentifier) { calendar in
                                        PeekCalendarAlertChip(
                                            title: calendar.title,
                                            color: Color(calendar.color),
                                            badgeOnly: calendarManager.badgeOnlyCalendarIDs.contains(calendar.calendarIdentifier),
                                            onToggle: { calendarManager.toggleBadgeOnly(calendar.calendarIdentifier) }
                                        )
                                    }
                                }
                                .padding([.horizontal, .bottom], PeekMetrics.cardContentPadding)
                                rowFootnote(
                                    NSLocalizedString("Click a calendar to show its events only in the menu bar.", comment: "Which meetings: badge-only calendars footnote"),
                                    isError: false
                                )
                            }
                        }
                    }

                    settingsGroup(NSLocalizedString("Muted and hidden events", comment: "Group label: per-event mute and hide")) {
                        let overrides = visibleOverrides
                        if overrides.isEmpty {
                            rowFootnote(
                                NSLocalizedString("Right-click an event in Peek to mute its alerts or hide it.", comment: "Muted and hidden events: empty state"),
                                isError: false
                            )
                        } else {
                            ForEach(Array(overrides.enumerated()), id: \.element.id) { index, entry in
                                if index > 0 { RowDivider() }
                                SettingRow(
                                    entry.title.isEmpty ? NSLocalizedString("Untitled Event", comment: "Fallback event title") : entry.title,
                                    subtitle: EventOverrideDescription.subtitle(for: entry)
                                ) {
                                    Button(NSLocalizedString("Restore", comment: "Muted and hidden events: restore button")) {
                                        calendarManager.removeOverride(id: entry.id)
                                    }
                                    .buttonStyle(SecondaryFillButtonStyle())
                                    .accessibilityLabel(Text(String(
                                        format: NSLocalizedString("Restore %@", comment: "Accessibility: restore a muted or hidden event; placeholder is the title"),
                                        entry.title
                                    )))
                                }
                            }
                        }
                    }

                    settingsGroup(NSLocalizedString("Joining a meeting", comment: "Group label: joining meetings")) {
                        SettingRow(
                            NSLocalizedString("Open in the native app", comment: "Native meeting app toggle"),
                            subtitle: NSLocalizedString("Zoom and Teams when installed, otherwise the browser.", comment: "Native meeting app subtitle")
                        ) {
                            switchToggle($calendarManager.openMeetingsInNativeApp, label: NSLocalizedString("Open in the native app", comment: "Native meeting app toggle"))
                        }
                        RowDivider()
                        SettingRow(
                            NSLocalizedString("Shortcut to join the next one", comment: "Join hotkey setting"),
                            subtitle: NSLocalizedString("Works even with the popover closed.", comment: "Join hotkey subtitle")
                        ) {
                            Picker("", selection: $calendarManager.joinHotkey) {
                                ForEach(JoinHotkeyOption.allCases, id: \.self) { Text($0.displayName).tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: PeekMetrics.pickerHotkey)
                            .accessibilityLabel(NSLocalizedString("Shortcut to join the next one", comment: "Join hotkey setting"))
                        }
                        if let joinHotkeyStatusMessage = calendarManager.joinHotkeyStatusMessage {
                            rowFootnote(joinHotkeyStatusMessage, isError: true)
                        }
                    }

                    settingsGroup(NSLocalizedString("Menu bar", comment: "Group label: menu bar")) {
                        SettingRow(NSLocalizedString("Show", comment: "Menu bar show setting")) {
                            Picker("", selection: showOptionBinding) {
                                ForEach(MenuBarShowOption.allCases, id: \.self) { Text($0.displayName).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: PeekMetrics.pickerShowSegmented)
                            .accessibilityLabel(NSLocalizedString("Show in the menu bar", comment: "Accessibility label for the menu bar show setting"))
                        }
                    }
                }
                if section == .prepared {
                    // Meeting context
                    settingsGroup(NSLocalizedString("Meeting context", comment: "Group label: meeting context")) {
                        SettingRow(
                            NSLocalizedString("Show who you're meeting", comment: "Contacts enrichment toggle"),
                            subtitle: NSLocalizedString("Match attendees with your Contacts for role and company. Stays on your Mac.", comment: "Contacts enrichment subtitle")
                        ) {
                            switchToggle(contactsContextBinding, label: NSLocalizedString("Show who you're meeting", comment: "Contacts enrichment toggle"))
                        }
                        if let contactsStatusMessage = calendarManager.contactsStatusMessage {
                            rowFootnote(contactsStatusMessage, isError: true)
                        }
                        RowDivider()
                        SettingRow(
                            NSLocalizedString("Context folder", comment: "Context folder setting"),
                            subtitle: calendarManager.contextFolderName.map {
                                String(format: NSLocalizedString("Reading %@ in “%@”.", comment: "Context folder chosen; file name and folder name"), MeetingContextFile.fileName, $0)
                            } ?? NSLocalizedString("Notes another app prepares for your meetings, such as a personal knowledge system.", comment: "Context folder subtitle")
                        ) {
                            HStack(spacing: PeekSpacing.sm) {
                                if calendarManager.contextFolderName != nil {
                                    Button(NSLocalizedString("Remove", comment: "Remove context folder")) {
                                        calendarManager.removeContextFolder()
                                    }
                                    .buttonStyle(SecondaryFillButtonStyle())
                                }
                                Button(NSLocalizedString("Choose…", comment: "Choose context folder")) {
                                    chooseContextFolder()
                                }
                                .buttonStyle(SecondaryFillButtonStyle())
                            }
                        }
                        if let contextFolderStatusMessage = calendarManager.contextFolderStatusMessage {
                            rowFootnote(contextFolderStatusMessage, isError: false)
                        }
                        if calendarManager.contextFolderName != nil {
                            RowDivider()
                            SettingRow(
                                NSLocalizedString("Show day priorities", comment: "Day priorities toggle"),
                                subtitle: NSLocalizedString("Today's priorities and links from the context file, above the next meeting.", comment: "Day priorities toggle subtitle")
                            ) {
                                switchToggle($calendarManager.showDayPriorities, label: NSLocalizedString("Show day priorities", comment: "Day priorities toggle"))
                            }
                        }
                    }
                    .onAppear { calendarManager.refreshContextFolderState() }


                    // Meeting brief
                    settingsGroup(NSLocalizedString("Meeting brief", comment: "Group label: meeting brief")) {
                        SettingRow(
                            NSLocalizedString("Brief before meetings", comment: "Meeting brief toggle"),
                            subtitle: NSLocalizedString("A few points on what to prepare, 15 minutes before a meeting with people or notes.", comment: "Meeting brief toggle subtitle")
                        ) {
                            switchToggle(briefEnabledBinding, label: NSLocalizedString("Brief before meetings", comment: "Meeting brief toggle"))
                        }
                        if briefService.isEnabled {
                            RowDivider()
                            SettingRow(NSLocalizedString("Written by", comment: "Brief engine setting")) {
                                Picker("", selection: briefEngineBinding) {
                                    ForEach(MeetingBriefService.EngineChoice.allCases, id: \.self) { Text($0.displayName).tag($0) }
                                }
                                .labelsHidden()
                                .frame(width: PeekMetrics.pickerWide)
                                .accessibilityLabel(NSLocalizedString("Written by", comment: "Brief engine setting"))
                            }
                            if let reason = briefService.availability(of: briefService.engineChoice).message {
                                rowFootnote(reason, isError: false)
                            }
                            if briefService.engineChoice == .cloud {
                                RowDivider()
                                SettingRow(
                                    NSLocalizedString("Anthropic API key", comment: "API key setting"),
                                    subtitle: hasAPIKey
                                        ? NSLocalizedString("Saved in your keychain.", comment: "API key saved subtitle")
                                        : NSLocalizedString("Stored in your keychain, never in Peek's files.", comment: "API key empty subtitle")
                                ) {
                                    HStack(spacing: PeekSpacing.sm) {
                                        if hasAPIKey {
                                            Button(NSLocalizedString("Remove", comment: "Remove API key")) {
                                                AnthropicKeyStore.delete()
                                                hasAPIKey = false
                                                briefService.keyDidChange()
                                            }
                                            .buttonStyle(SecondaryFillButtonStyle())
                                        } else {
                                            SecureField(NSLocalizedString("sk-ant-…", comment: "API key field placeholder"), text: $apiKeyDraft)
                                                .textFieldStyle(.roundedBorder)
                                                .frame(width: PeekMetrics.pickerWide)
                                                .onSubmit(saveAPIKey)
                                                .accessibilityLabel(NSLocalizedString("Anthropic API key", comment: "API key setting"))
                                            Button(NSLocalizedString("Save", comment: "Save API key")) {
                                                saveAPIKey()
                                            }
                                            .buttonStyle(SecondaryFillButtonStyle())
                                            .disabled(apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                        }
                                    }
                                }
                                if let apiKeyMessage {
                                    rowFootnote(apiKeyMessage, isError: true)
                                }
                            }
                            RowDivider()
                            VStack(alignment: .leading, spacing: PeekSpacing.sm) {
                                SettingRow(
                                    NSLocalizedString("Never brief", comment: "Brief exclusion keywords setting"),
                                    subtitle: NSLocalizedString("Meetings whose title or notes contain these words.", comment: "Brief exclusion keywords subtitle")
                                ) {
                                    EmptyView()
                                }
                                KeywordChipEditor(text: briefKeywordsBinding)
                                    .padding([.horizontal, .bottom], PeekMetrics.cardContentPadding)
                            }
                        }
                    }
                }
                if section == .general {
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


                    settingsGroup(NSLocalizedString("Menu bar and shortcut", comment: "Group label: menu bar details and the global shortcut")) {
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
                        SettingRow(NSLocalizedString("Space policy", comment: "Space policy setting")) {
                            Picker("", selection: $calendarManager.menuBarSpacePolicy) {
                                ForEach(MenuBarSpacePolicy.allCases, id: \.self) { Text($0.displayName).tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: PeekMetrics.pickerWide)
                            .accessibilityLabel(NSLocalizedString("Space policy", comment: "Accessibility label for space policy"))
                        }
                        RowDivider()
                        SettingRow(
                            NSLocalizedString("Count down to meetings only", comment: "Status bar: only meetings toggle"),
                            subtitle: NSLocalizedString("Skip events without a join link. Declined events follow the Filters tab.", comment: "Status bar: only meetings subtitle")
                        ) {
                            switchToggle($calendarManager.statusBarOnlyMeetings, label: NSLocalizedString("Count down to meetings only", comment: "Status bar: only meetings toggle"))
                        }
                        RowDivider()
                        SettingRow(
                            NSLocalizedString("Name in the menu bar", comment: "Status bar label setting"),
                            subtitle: NSLocalizedString("A person's name needs attendees, Contacts or a context folder.", comment: "Status bar label subtitle")
                        ) {
                            Picker("", selection: $calendarManager.statusBarLabelStyle) {
                                ForEach(StatusBarLabelStyle.allCases, id: \.self) { Text($0.displayName).tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: PeekMetrics.pickerWide)
                            .accessibilityLabel(NSLocalizedString("Name in the menu bar", comment: "Status bar label setting"))
                        }
                        RowDivider()
                        SettingRow(
                            NSLocalizedString("Use urgency colors", comment: "Urgency colors toggle"),
                            subtitle: NSLocalizedString("Amber, then red, as the meeting gets close.", comment: "Urgency colors subtitle")
                        ) {
                            switchToggle($calendarManager.urgencyColorsEnabled, label: NSLocalizedString("Use urgency colors", comment: "Urgency colors toggle"))
                        }
                        RowDivider()
                        SettingRow(
                            NSLocalizedString("Show month calendar", comment: "Month view toggle"),
                            subtitle: NSLocalizedString("A compact month above your events. Choose a day to see its agenda.", comment: "Month view toggle subtitle")
                        ) {
                            switchToggle($calendarManager.showMonthCalendar, label: NSLocalizedString("Show month calendar", comment: "Month view toggle"))
                        }
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


                    // Time zones
                    settingsGroup(NSLocalizedString("Time zones", comment: "Group label: time zones")) {
                        VStack(alignment: .leading, spacing: PeekSpacing.sm) {
                            SettingRow(
                                NSLocalizedString("World clocks", comment: "World clocks setting"),
                                subtitle: NSLocalizedString("Shown under the date, and next to each meeting's time when you expand it.", comment: "World clocks subtitle")
                            ) {
                                Menu(NSLocalizedString("Add city…", comment: "Add world clock city")) {
                                    ForEach(WorldClock.suggestedIdentifiers.filter { !calendarManager.worldClockZones.contains($0) }, id: \.self) { identifier in
                                        Button(WorldClock.cityName(for: identifier)) {
                                            calendarManager.addWorldClock(identifier)
                                        }
                                    }
                                }
                                .fixedSize()
                                .disabled(calendarManager.worldClockZones.count >= WorldClock.maxZones)
                                .accessibilityLabel(NSLocalizedString("Add city…", comment: "Add world clock city"))
                            }
                            if !calendarManager.worldClockZones.isEmpty {
                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: PeekMetrics.chipMinWidth), spacing: PeekSpacing.iconGap, alignment: .leading)],
                                    alignment: .leading,
                                    spacing: PeekSpacing.iconGap
                                ) {
                                    ForEach(calendarManager.worldClockZones, id: \.self) { identifier in
                                        PeekKeywordChip(
                                            title: WorldClock.cityName(for: identifier),
                                            removeHelp: NSLocalizedString("Remove city", comment: "World clock chip remove help")
                                        ) {
                                            calendarManager.removeWorldClock(identifier)
                                        }
                                    }
                                }
                                .padding([.horizontal, .bottom], PeekMetrics.cardContentPadding)
                            }
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

                    // Diagnostics (PEEK-275)
                    settingsGroup(NSLocalizedString("Diagnostics", comment: "Group label: local diagnostics")) {
                        SettingRow(
                            NSLocalizedString("Export diagnostics", comment: "Diagnostics export setting"),
                            subtitle: NSLocalizedString("Saves a file on this Mac with Peek's recent activity and crash reports, without meeting details. Nothing is sent; you decide whether to share it.", comment: "Diagnostics export subtitle")
                        ) {
                            Button(NSLocalizedString("Export…", comment: "Diagnostics export button")) {
                                exportDiagnostics()
                            }
                            .buttonStyle(SecondaryFillButtonStyle())
                            .accessibilityLabel(NSLocalizedString("Export diagnostics", comment: "Diagnostics export setting"))
                        }
                        if let diagnosticsMessage {
                            rowFootnote(diagnosticsMessage, isError: diagnosticsFailed)
                        }
                    }

                }
            }
            .padding(PeekSpacing.xl)
        }
    }

    private var briefEnabledBinding: Binding<Bool> {
        Binding(
            get: { briefService.isEnabled },
            set: { briefService.setEnabled($0) }
        )
    }

    private var briefEngineBinding: Binding<MeetingBriefService.EngineChoice> {
        Binding(
            get: { briefService.engineChoice },
            set: { choice in
                if choice == .cloud && !briefService.hasCloudConsent {
                    briefService.setEngine(.cloud, consented: Self.askCloudConsent())
                } else {
                    briefService.setEngine(choice)
                }
            }
        )
    }

    private var briefKeywordsBinding: Binding<String> {
        Binding(
            get: { briefService.excludedKeywordsText },
            set: { briefService.setExcludedKeywords($0) }
        )
    }

    private func saveAPIKey() {
        if AnthropicKeyStore.save(apiKeyDraft) {
            apiKeyDraft = ""
            apiKeyMessage = nil
            hasAPIKey = true
            briefService.keyDidChange()
        } else {
            apiKeyMessage = NSLocalizedString("Couldn't save the key to your keychain.", comment: "API key save failed")
        }
    }

    /// The consent screen for sending meeting details to Claude (PEEK-223).
    /// It lists exactly the fields in `BriefInput`.
    static func askCloudConsent() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = NSLocalizedString("Send meeting details to Claude?", comment: "Cloud consent title")
        alert.informativeText = NSLocalizedString(
            "For each meeting that gets a brief, Peek sends Anthropic, using your API key: the title, how soon it starts, the names and roles of the people, your notes about them, the cleaned-up invitation text, and the summary and points from your context folder.\n\nPeek never sends email addresses, locations, meeting links, calendar names or replies. Anthropic's terms for your API account apply. You can switch back to “On this Mac” at any time.",
            comment: "Cloud consent body; lists the fields sent and not sent"
        )
        alert.addButton(withTitle: NSLocalizedString("Use Claude", comment: "Cloud consent accept"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cloud consent cancel"))
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    private var contactsContextBinding: Binding<Bool> {
        Binding(
            get: { calendarManager.meetingContextUsesContacts },
            set: { calendarManager.setContactsContext(enabled: $0) }
        )
    }

    private func chooseContextFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = NSLocalizedString("Use Folder", comment: "Context folder open panel button")
        panel.message = String(
            format: NSLocalizedString("Choose the folder where %@ is written. Peek only reads it.", comment: "Context folder open panel message"),
            MeetingContextFile.fileName
        )
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            calendarManager.setContextFolder(url)
        }
    }

    // MARK: Alert ladder

    /// The lead time of the first step; the old "Disabled" timing reads as 10 minutes.
    private var leadTime: NotificationTiming {
        calendarManager.notificationTiming == .none ? .tenMinutes : calendarManager.notificationTiming
    }

    /// Calendars Peek reads, for the badge-only chips.
    private var alertCalendars: [EKCalendar] {
        CalendarManager.selectedCalendars(
            from: calendarManager.getAllCalendars(),
            enabledIDs: calendarManager.enabledCalendarIDs,
            hasCustomSelection: calendarManager.hasCustomCalendarSelection
        )
        .sorted { $0.title < $1.title }
    }

    /// Per-event choices still in effect, for the list (PEEK-273).
    private var visibleOverrides: [EventOverride] {
        let now = Date()
        return calendarManager.eventOverrides.sortedForDisplay.filter { entry in
            entry.expiresAt.map { $0 > now } ?? true
        }
    }

    private var beforeLevelBinding: Binding<AlertLevel> {
        Binding(
            get: { calendarManager.notificationsEnabled && calendarManager.notificationTiming != .none ? .notification : .off },
            set: { level in
                if level == .notification && calendarManager.notificationTiming == .none {
                    calendarManager.notificationTiming = .tenMinutes
                }
                calendarManager.notificationsEnabled = level == .notification
            }
        )
    }

    private var soonLevelBinding: Binding<AlertLevel> {
        Binding(
            get: { calendarManager.soonCardEnabled ? .headsUp : .off },
            set: { calendarManager.soonCardEnabled = $0 == .headsUp }
        )
    }

    private var startLevelBinding: Binding<AlertLevel> {
        Binding(
            get: { AlertLevel(calendarManager.startAlertStyle) },
            set: { calendarManager.startAlertStyle = $0.startAlertStyle }
        )
    }

    private var showOptionBinding: Binding<MenuBarShowOption> {
        Binding(
            get: { MenuBarShowOption(mode: calendarManager.statusBarMode, spacePolicy: calendarManager.menuBarSpacePolicy) },
            set: { option in
                let applied = option.apply(currentPolicy: calendarManager.menuBarSpacePolicy)
                if let mode = applied.mode {
                    calendarManager.statusBarMode = mode
                }
                if calendarManager.menuBarSpacePolicy != applied.policy {
                    calendarManager.menuBarSpacePolicy = applied.policy
                }
            }
        )
    }

    private func ladderTitle(_ text: String) -> some View {
        Text(text)
            .font(PeekFont.rowTitle)
            .foregroundColor(PeekColor.ink)
    }

    private func ladderRow<Title: View, Level: View>(
        hint: String,
        @ViewBuilder title: () -> Title,
        @ViewBuilder level: () -> Level
    ) -> some View {
        HStack(alignment: .center, spacing: PeekSpacing.md) {
            VStack(alignment: .leading, spacing: PeekSpacing.xxs) {
                title()
                Text(hint)
                    .font(PeekFont.caption)
                    .foregroundColor(PeekColor.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: PeekSpacing.md)
            level()
        }
        .padding(PeekMetrics.settingRowInsets)
    }

    private func levelPicker(_ selection: Binding<AlertLevel>, options: [AlertLevel], label: String) -> some View {
        Picker("", selection: selection) {
            ForEach(options, id: \.self) { Text($0.displayName).tag($0) }
        }
        .labelsHidden()
        .frame(width: PeekMetrics.pickerLevel)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private func settingsGroup<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            GroupLabel(label)
            InsetCard { content() }
        }
    }

    private func exportDiagnostics() {
        DiagnosticsExporter.exportAndReveal(calendarManager: calendarManager) { result in
            switch result {
            case .success(let url):
                diagnosticsFailed = false
                diagnosticsMessage = String(
                    format: NSLocalizedString("Saved %@ and showed it in the Finder.", comment: "Diagnostics exported; placeholder is the file name"),
                    url.lastPathComponent
                )
            case .failure:
                diagnosticsFailed = true
                diagnosticsMessage = NSLocalizedString("Couldn't save the diagnostics file.", comment: "Diagnostics export failed")
            }
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

// MARK: - Muted and hidden events (PEEK-273)

/// "Alerts muted · Tue 1 Dec at 10:00", "Hidden · every event in the series".
enum EventOverrideDescription {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    static func subtitle(for entry: EventOverride) -> String {
        let action: String
        switch entry.action {
        case .mute:
            action = NSLocalizedString("Alerts muted", comment: "Muted event indicator")
        case .hide:
            action = NSLocalizedString("Hidden", comment: "Muted and hidden events: the event is hidden")
        }
        let when: String
        if entry.scope == .series {
            when = NSLocalizedString("every event in the series", comment: "Muted and hidden events: the choice covers a whole recurring series")
        } else if let date = entry.occurrenceDate {
            when = dateFormatter.string(from: date)
        } else {
            return action
        }
        return String(format: NSLocalizedString("%@ · %@", comment: "Two parts joined with a middle dot"), action, when)
    }
}
