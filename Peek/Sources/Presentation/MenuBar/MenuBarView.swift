import SwiftUI
import EventKit
import Foundation

struct MenuBarView: View {
    // Key codes
    private static let kEscapeKeyCode: UInt16 = 53
    private static let kReturnKeyCode: UInt16 = 36
    private static let kSpaceKeyCode: UInt16 = 49
    private static let kDownArrowKeyCode: UInt16 = 125
    private static let kUpArrowKeyCode: UInt16 = 126

    @ObservedObject var calendarManager: CalendarManager
    @State private var showingPreferences = false
    @State private var selectedEventIndex: Int = 0
    @State private var eventMonitor: Any?
    @State private var isRefreshing = false
    @State private var showRefreshConfirmation = false
    var closePopover: (() -> Void)?
    var refreshStatusBar: ((EKEvent?) -> Void)? = nil
    private let refreshFeedbackMinDuration: TimeInterval = 0.4
    private let refreshConfirmationDuration: TimeInterval = 0.9

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

    private var refreshHelpText: String {
        if !calendarManager.hasCalendarAccess {
            return NSLocalizedString("No Calendar Access", comment: "Refresh help text when calendar access is missing")
        }
        if isRefreshing {
            return NSLocalizedString("Refreshing...", comment: "Refresh help text while refreshing")
        }
        if showRefreshConfirmation {
            return NSLocalizedString("Refreshed", comment: "Refresh help text after refresh completes")
        }
        return NSLocalizedString("Refresh", comment: "Help text: Refresh")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header remains visible in loading, permission, empty, and event states.
            HStack(spacing: 8) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .frame(width: 26, height: 26)
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Peek")
                        .font(.headline)
                    Text("Your next event, at a glance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !calendarManager.upcomingEvents.isEmpty {
                    Text("\(calendarManager.upcomingEvents.count)")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.14))
                        .clipShape(Capsule())
                        .accessibilityLabel(
                            String(format: NSLocalizedString("%d upcoming events", comment: "Accessibility label for event count badge"), calendarManager.upcomingEvents.count)
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            if calendarManager.upcomingEvents.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: calendarManager.hasCalendarAccess ? "calendar.badge.clock" : "calendar.badge.exclamationmark")
                        .font(.system(size: 30, weight: .light))
                        .foregroundColor(.accentColor)
                        .accessibilityHidden(true)

                    Text(
                        calendarManager.hasCalendarAccess
                            ? NSLocalizedString("No upcoming events", comment: "Empty event state title")
                            : NSLocalizedString("No Calendar Access", comment: "Missing calendar permission title")
                    )
                        .font(.headline)

                    Text(
                        calendarManager.hasCalendarAccess
                            ? NSLocalizedString(
                                "Peek will update automatically when an event is added.",
                                comment: "Empty event state explanation"
                            )
                            : NSLocalizedString(
                                "Grant permission in System Settings → Privacy & Security → Calendars",
                                comment: "Calendar permission recovery guidance"
                            )
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 270)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
            } else {
                // Event list
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(calendarManager.upcomingEvents.enumerated()), id: \.element.eventIdentifier) { index, event in
                            EventDetailView(event: event, isFirst: index == 0, isSelected: index == selectedEventIndex)
                                .contextMenu {
                                    EventContextMenu(event: event)
                                }

                            if index < calendarManager.upcomingEvents.count - 1 {
                                Divider()
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .frame(maxHeight: 400)
            }

            Divider()

            HStack(spacing: 16) {
                Button(action: {
                    showingPreferences = true
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(NSLocalizedString("Preferences", comment: "Help text: Preferences"))
                .accessibilityLabel(Text("Preferences"))

                Spacer()

                Button(action: {
                    performRefresh()
                }) {
                    ZStack {
                        if isRefreshing {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .controlSize(.small)
                        } else if showRefreshConfirmation {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.system(size: 16))
                    .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing || !calendarManager.hasCalendarAccess)
                .help(refreshHelpText)
                .accessibilityLabel(Text("Refresh"))

                Button(action: {
                    let calendarURL = URL(fileURLWithPath: "/System/Applications/Calendar.app")
                    NSWorkspace.shared.openApplication(at: calendarURL, configuration: NSWorkspace.OpenConfiguration())
                }) {
                    Image(systemName: "calendar")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(NSLocalizedString("Open Calendar", comment: "Help text: Open Calendar"))
                .accessibilityLabel(Text("Open Calendar"))

                Spacer()

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "power")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(NSLocalizedString("Quit Peek", comment: "Help text: Quit Peek"))
                .accessibilityLabel(Text("Quit Peek"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 350)
        .fixedSize(horizontal: false, vertical: true)
        .preferredColorScheme(preferredColorScheme)
        .sheet(isPresented: $showingPreferences) {
            PreferencesView(calendarManager: calendarManager)
        }
        .onAppear {
            if let existingMonitor = eventMonitor {
                NSEvent.removeMonitor(existingMonitor)
            }
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                self.handleKeyPress(event)
            }
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
        .onChange(of: calendarManager.upcomingEvents.count) { newCount in
            // Reset selected index if it's out of bounds
            if selectedEventIndex >= newCount {
                selectedEventIndex = max(0, newCount - 1)
            }
        }
    }

    private func handleKeyPress(_ event: NSEvent) -> NSEvent? {
        if showingPreferences || NSApp.keyWindow?.attachedSheet != nil {
            return event
        }

        if let textView = NSApp.keyWindow?.firstResponder as? NSTextView,
           textView.isFieldEditor || textView.isEditable {
            return event
        }

        // Esc key to close popover
        if event.keyCode == Self.kEscapeKeyCode {
            closePopover?()
            return nil
        }

        // Arrow key navigation (only if we have events and not in text field)
        if !calendarManager.upcomingEvents.isEmpty {
            if event.keyCode == Self.kDownArrowKeyCode {
                selectedEventIndex = min(selectedEventIndex + 1, calendarManager.upcomingEvents.count - 1)
                return nil
            } else if event.keyCode == Self.kUpArrowKeyCode {
                selectedEventIndex = max(selectedEventIndex - 1, 0)
                return nil
            } else if event.keyCode == Self.kReturnKeyCode || event.keyCode == Self.kSpaceKeyCode {
                openMeetingLinkForSelectedEvent()
                return nil
            }
        }

        return event
    }

    private func openMeetingLinkForSelectedEvent() {
        guard !calendarManager.upcomingEvents.isEmpty else { return }
        let event = calendarManager.upcomingEvents[selectedEventIndex]
        if let url = MeetingURLDetector.extract(from: event), MeetingURLDetector.isURLSafe(url) {
            NSWorkspace.shared.open(url)
        }
    }

    private func performRefresh() {
        guard !isRefreshing else { return }

        isRefreshing = true
        showRefreshConfirmation = false
        let startTime = Date()

        calendarManager.fetchNextEvent { event in
            refreshStatusBar?(event)

            let elapsed = Date().timeIntervalSince(startTime)
            let delay = max(0, refreshFeedbackMinDuration - elapsed)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                isRefreshing = false
                showRefreshConfirmation = true

                DispatchQueue.main.asyncAfter(deadline: .now() + refreshConfirmationDuration) {
                    showRefreshConfirmation = false
                }
            }
        }
    }
}

struct EventDetailView: View {
    let event: EKEvent
    var isFirst: Bool = false
    var isSelected: Bool = false
    @Environment(\.colorScheme) var colorScheme

    private var meetingURL: URL? {
        MeetingURLDetector.extract(from: event)
    }

    private var accessibilityLabelText: String {
        var parts: [String] = []
        parts.append(event.title ?? NSLocalizedString("Untitled Event", comment: "Fallback title for untitled events"))

        if event.isAllDay {
            parts.append(EventTimeFormatter.compactDateText(for: event.startDate))
            parts.append(NSLocalizedString("All day", comment: "Accessibility label segment for all-day events"))
        } else {
            parts.append(EventTimeFormatter.timeRangeText(start: event.startDate, end: event.endDate))
            if isFirst && event.startDate > Date() {
                parts.append(EventTimeFormatter.timeUntilText(target: event.startDate))
            }
        }

        if let location = event.location, !location.isEmpty {
            parts.append(location)
        }

        if let calendar = event.calendar {
            parts.append(calendar.title)
        }

        if meetingURL != nil {
            parts.append(NSLocalizedString("Has meeting link", comment: "Accessibility label segment when event has a meeting link"))
        }

        return parts.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Event title with badge for first event
            HStack(alignment: .top, spacing: 6) {
                Text(event.title ?? NSLocalizedString("Untitled Event", comment: "Fallback title for untitled events"))
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(isSelected ? .accentColor : .primary)

                if isFirst && event.startDate > Date() {
                    Text("NEXT")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .cornerRadius(3)
                }

                Spacer()
            }

            // Date and time - compact view
            HStack(spacing: 14) {
                Image(systemName: event.isAllDay ? "calendar" : "clock")
                    .foregroundColor(event.isAllDay ? .orange : .blue)
                    .frame(width: 16)
                    .font(.system(size: 12))

                if event.isAllDay {
                    HStack(spacing: 6) {
                        Text(EventTimeFormatter.compactDateText(for: event.startDate))
                            .font(.subheadline)
                        Text("ALL DAY")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .cornerRadius(3)
                    }
                } else {
                    Text(EventTimeFormatter.timeRangeText(start: event.startDate, end: event.endDate))
                        .font(.subheadline)
                }

                Spacer()

                // Time until event - inline for first event (not for all-day events)
                if isFirst && event.startDate > Date() && !event.isAllDay {
                    Text(EventTimeFormatter.timeUntilText(target: event.startDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Location and Calendar in one row
            HStack(spacing: 12) {
                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "location")
                            .foregroundColor(.red)
                            .frame(width: 16)
                            .font(.system(size: 12))
                        Text(location)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }

                if let calendar = event.calendar {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(calendar.color))
                            .frame(width: 8, height: 8)
                        Text(calendar.title)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }

            // Meeting join button (if URL detected)
            if let meetingURL = meetingURL {
                Button(action: {
                    if MeetingURLDetector.isURLSafe(meetingURL) {
                        NSWorkspace.shared.open(meetingURL)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 11))
                        Text("Join Meeting")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

        }
        .padding(8)
        .background(
            isSelected
                ? (colorScheme == .dark
                    ? Color.white.opacity(0.05)
                    : Color.black.opacity(0.03))
                : Color.clear
        )
        .cornerRadius(6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

}

// MARK: - Event Context Menu
struct EventContextMenu: View {
    let event: EKEvent

    private var meetingURL: URL? {
        MeetingURLDetector.extract(from: event)
    }

    var body: some View {
        if let meetingURL = meetingURL {
            Button("Copy Meeting Link") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(meetingURL.absoluteString, forType: .string)
            }

            Divider()
        }

        Button("Open in Calendar") {
            let calendarURL = URL(fileURLWithPath: "/System/Applications/Calendar.app")
            NSWorkspace.shared.openApplication(at: calendarURL, configuration: NSWorkspace.OpenConfiguration())
        }

        if let location = event.location, !location.isEmpty {
            Button("Copy Location") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(location, forType: .string)
            }
        }

        Button("Copy Event Title") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(event.title ?? "", forType: .string)
        }
    }

}
