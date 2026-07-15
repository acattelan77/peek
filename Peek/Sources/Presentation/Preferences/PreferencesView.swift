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
        case .auto:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom tab bar
            HStack(spacing: 0) {
                TabButton(title: NSLocalizedString("Calendars", comment: "Preferences tab title"), isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                TabButton(title: NSLocalizedString("Filters", comment: "Preferences tab title"), isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                TabButton(title: NSLocalizedString("General", comment: "Preferences tab title"), isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Tab content
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

            Divider()

            if let feedback = importExportFeedback {
                HStack(spacing: 4) {
                    Image(systemName: feedback.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .accessibilityHidden(true)
                    Text(feedback.message)
                        .font(.caption)
                }
                .foregroundColor(feedback.isError ? .red : .green)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            // Bottom buttons
            HStack {
                Button("Export Settings...") {
                    exportSettings()
                }
                .buttonStyle(.bordered)

                Button("Import Settings...") {
                    importSettings()
                }
                .buttonStyle(.bordered)

                Spacer()

                Text(AppVersion.from().displayText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityLabel(AppVersion.from().displayText)

                Button("Done") {
                    calendarManager.savePreferences()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 700)
        .fixedSize()
        .preferredColorScheme(preferredColorScheme)
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
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Calendars to Monitor")
                .font(.headline)

            Text("Choose which calendars to display in the menu bar")
                .font(.caption)
                .foregroundColor(.secondary)

            if !calendarManager.hasCalendarAccess {
                Text("Calendar access not granted")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if availableCalendars.isEmpty {
                Text("No calendars found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(availableCalendars, id: \.calendarIdentifier) { calendar in
                            CalendarCheckboxRow(
                                calendar: calendar,
                                isEnabled: calendarManager.isCalendarEnabled(calendar.calendarIdentifier)
                            ) {
                                calendarManager.toggleCalendar(calendar.calendarIdentifier)
                            }
                        }
                    }
                }

                HStack {
                    Button("Select All") {
                        for calendar in availableCalendars {
                            if !calendarManager.isCalendarEnabled(calendar.calendarIdentifier) {
                                calendarManager.toggleCalendar(calendar.calendarIdentifier)
                            }
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Deselect All") {
                        for calendar in availableCalendars {
                            if calendarManager.isCalendarEnabled(calendar.calendarIdentifier) {
                                calendarManager.toggleCalendar(calendar.calendarIdentifier)
                            }
                        }
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }
            }
        }
        .padding()
    }
}

// MARK: - Filters Tab
struct FiltersTab: View {
    @ObservedObject var calendarManager: CalendarManager

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Event Filters")
                .font(.headline)

            Text("Control which events are displayed")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Hide All-Day Events", isOn: $calendarManager.hideAllDayEvents)

                Toggle("Hide Declined Events", isOn: $calendarManager.hideDeclinedEvents)

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Filter out events containing keywords (comma-separated):")
                        .font(.caption)

                    TextField("e.g., canceled, optional, tentative", text: $calendarManager.filterKeywords)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Spacer()
        }
        .padding()
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
            VStack(alignment: .leading, spacing: 24) {
                // Launch at Login
                Toggle("Launch at Login", isOn: launchAtLoginBinding)

                if let launchAtLoginErrorMessage {
                    Text(launchAtLoginErrorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Divider()

                // Calendar Settings
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Look ahead:")
                            .frame(width: 140, alignment: .leading)
                        Picker("", selection: $calendarManager.lookaheadDays) {
                            Text("Today only").tag(1)
                            Text("Next 3 days").tag(3)
                            Text("Next 7 days").tag(7)
                            Text("Next 14 days").tag(14)
                            Text("Next 30 days").tag(30)
                        }
                        .labelsHidden()
                        Spacer()
                    }

                    HStack {
                        Text("Max events to show:")
                            .frame(width: 140, alignment: .leading)
                        Picker("", selection: $calendarManager.maxEventsToShow) {
                            Text("3").tag(3)
                            Text("5").tag(5)
                            Text("10").tag(10)
                            Text("15").tag(15)
                            Text("20").tag(20)
                        }
                        .labelsHidden()
                        Spacer()
                    }
                }

                Divider()

                // Status Bar Display
                VStack(alignment: .leading, spacing: 12) {
                    Text("Status Bar Display")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Display format:")
                            .font(.subheadline)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(StatusBarDisplayMode.allCases, id: \.self) { mode in
                                HStack {
                                    Image(systemName: calendarManager.statusBarMode == mode ? "circle.fill" : "circle")
                                        .foregroundColor(calendarManager.statusBarMode == mode ? .accentColor : .secondary)
                                        .font(.system(size: 12))
                                    Text(mode.displayName)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    calendarManager.statusBarMode = mode
                                }
                            }
                        }
                        .padding(.leading, 4)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Space policy:")
                            .font(.subheadline)
                            .padding(.top, 4)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(MenuBarSpacePolicy.allCases, id: \.self) { policy in
                                HStack {
                                    Image(systemName: calendarManager.menuBarSpacePolicy == policy ? "circle.fill" : "circle")
                                        .foregroundColor(calendarManager.menuBarSpacePolicy == policy ? .accentColor : .secondary)
                                        .font(.system(size: 12))
                                    Text(policy.displayName)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    calendarManager.menuBarSpacePolicy = policy
                                }
                            }
                        }
                        .padding(.leading, 4)
                    }

                    Toggle("Show event count badge", isOn: $calendarManager.showEventCount)
                        .padding(.top, 8)

                    Toggle("Use urgency colors", isOn: $calendarManager.urgencyColorsEnabled)
                }

                Divider()

                // Appearance
                VStack(alignment: .leading, spacing: 12) {
                    Text("Appearance")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            HStack {
                                Image(systemName: calendarManager.appearanceMode == mode ? "circle.fill" : "circle")
                                    .foregroundColor(calendarManager.appearanceMode == mode ? .accentColor : .secondary)
                                    .font(.system(size: 12))
                                Text(mode.displayName)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                calendarManager.appearanceMode = mode
                            }
                        }
                    }
                    .padding(.leading, 4)
                }

                Divider()

                // Global Hotkey
                VStack(alignment: .leading, spacing: 12) {
                    Text("Global Hotkey")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(HotkeyOption.allCases, id: \.self) { option in
                            HStack {
                                Image(systemName: calendarManager.globalHotkey == option ? "circle.fill" : "circle")
                                    .foregroundColor(calendarManager.globalHotkey == option ? .accentColor : .secondary)
                                    .font(.system(size: 12))
                                Text(option.rawValue)
                                    .font(.system(.body, design: .monospaced))
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                calendarManager.globalHotkey = option
                            }
                        }
                    }
                    .padding(.leading, 4)

                    if let hotkeyStatusMessage = calendarManager.hotkeyStatusMessage {
                        Text(hotkeyStatusMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    } else {
                        Text("Changes take effect immediately")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }

                Divider()

                // Notifications
                VStack(alignment: .leading, spacing: 12) {
                    Text("Notifications")
                        .font(.headline)

                    Toggle("Enable event notifications", isOn: $calendarManager.notificationsEnabled)

                    if calendarManager.notificationsEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(NotificationTiming.allCases, id: \.self) { timing in
                                HStack {
                                    Image(systemName: calendarManager.notificationTiming == timing ? "circle.fill" : "circle")
                                        .foregroundColor(calendarManager.notificationTiming == timing ? .accentColor : .secondary)
                                        .font(.system(size: 12))
                                    Text(timing.displayName)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    calendarManager.notificationTiming = timing
                                }
                            }
                        }
                        .padding(.leading, 20)

                        Text("Notifications include meeting links when available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                            .padding(.top, 4)
                    }
                }
            }
            .padding(20)
        }
    }
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
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)

                Rectangle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Calendar Checkbox Row
struct CalendarCheckboxRow: View {
    let calendar: EKCalendar
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: isEnabled ? "checkmark.square.fill" : "square")
                    .foregroundColor(isEnabled ? .blue : .gray)

                Circle()
                    .fill(Color(calendar.color))
                    .frame(width: 12, height: 12)

                Text(calendar.title)
                    .foregroundColor(.primary)

                Spacer()

                Text(calendarTypeDescription(calendar.type))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }

    private func calendarTypeDescription(_ type: EKCalendarType) -> String {
        switch type {
        case .local:
            return NSLocalizedString("Local", comment: "Calendar type: local")
        case .calDAV:
            return NSLocalizedString("CalDAV", comment: "Calendar type: CalDAV")
        case .exchange:
            return NSLocalizedString("Exchange", comment: "Calendar type: Exchange")
        case .subscription:
            return NSLocalizedString("Subscription", comment: "Calendar type: subscription")
        case .birthday:
            return NSLocalizedString("Birthday", comment: "Calendar type: birthday")
        @unknown default:
            return ""
        }
    }
}
