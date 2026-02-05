import SwiftUI
import EventKit
import Foundation

struct MenuBarView: View {
    // Key codes
    private static let kEscapeKeyCode: UInt16 = 53
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
            if calendarManager.upcomingEvents.isEmpty {
                Text("No upcoming events")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                // Header with branding
                HStack(spacing: 8) {
                    Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                        .resizable()
                        .frame(width: 24, height: 24)
                        .cornerRadius(6)

                    Text("Peek")
                        .font(.system(size: 18, weight: .semibold))

                    Spacer()

                    Text("\(calendarManager.upcomingEvents.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Divider()

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
            }
        }

        return event
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
                        .font(.system(size: 9, weight: .bold))
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
                            .font(.system(size: 10, weight: .semibold))
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
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .foregroundColor(.red)
                            .frame(width: 16)
                            .font(.system(size: 12))
                        Text(location)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(event.calendar.color))
                        .frame(width: 8, height: 8)
                    Text(event.calendar.title)
                        .font(.caption)
                        .lineLimit(1)
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
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(4)
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
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
