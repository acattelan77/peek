import SwiftUI
import EventKit

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
            return "No calendar access"
        }
        if isRefreshing {
            return "Refreshing..."
        }
        if showRefreshConfirmation {
            return "Refreshed"
        }
        return "Refresh"
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
                .help("Preferences")

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
                .help("Open Calendar")

                Spacer()

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "power")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Quit Peek")
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

    // Cached formatters for performance
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private static let compactDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private var meetingURL: URL? {
        extractMeetingURL(from: event)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Event title with badge for first event
            HStack(alignment: .top, spacing: 6) {
                Text(event.title ?? "Untitled Event")
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
                        Text("\(Self.compactDateFormatter.string(from: event.startDate))")
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
                    Text("\(Self.compactDateFormatter.string(from: event.startDate)) • \(Self.timeFormatter.string(from: event.startDate)) - \(Self.timeFormatter.string(from: event.endDate))")
                        .font(.subheadline)
                }

                Spacer()

                // Time until event - inline for first event (not for all-day events)
                if isFirst && event.startDate > Date() && !event.isAllDay {
                    Text(timeUntilEvent(event.startDate))
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
                    if isURLSafe(meetingURL) {
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

            // Ask Claude button
            Button(action: {
                openClaudeWithMeetingContext()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                    Text("Ask Claude about this meeting")
                        .font(.caption)
                }
                .foregroundColor(.purple)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
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

    private func extractMeetingURL(from event: EKEvent) -> URL? {
        // Simplified, safer URL patterns (reduced ReDoS risk)
        let patterns = [
            "https://[a-zA-Z0-9.-]+\\.zoom\\.us/j/[0-9]+",
            "https://meet\\.google\\.com/[a-z-]+",
            "https://teams\\.microsoft\\.com/l/meetup-join/[^\\s]+",
            "https://[a-zA-Z0-9.-]+\\.webex\\.com/[^\\s]+",
            "https://[a-zA-Z0-9.-]+\\.gotomeeting\\.com/[^\\s]+",
            "https://whereby\\.com/[a-z0-9-]+",
            "https://discord\\.gg/[a-zA-Z0-9]+",
            "https://discord\\.com/[^\\s]+"
        ]

        // Check event notes (limit length to prevent ReDoS)
        if let notes = event.notes?.prefix(2000) {
            if let url = findURLInText(String(notes), patterns: patterns) {
                return url
            }
        }

        // Check event location (limit length)
        if let location = event.location?.prefix(500) {
            if let url = findURLInText(String(location), patterns: patterns) {
                return url
            }
        }

        // Check event URL property
        if let url = event.url, isURLSafe(url) {
            return url
        }

        return nil
    }

    private func findURLInText(_ text: String, patterns: [String]) -> URL? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                continue
            }

            // Use firstMatch with limited range for safety
            if let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                let urlString = String(text[range])
                if let url = URL(string: urlString), isURLSafe(url) {
                    return url
                }
            }
        }
        return nil
    }

    private func isURLSafe(_ url: URL) -> Bool {
        // Only allow https URLs from known meeting providers
        guard let scheme = url.scheme?.lowercased(), scheme == "https" else {
            return false
        }

        guard let host = url.host?.lowercased() else {
            return false
        }

        // Allowlist of trusted meeting domains
        let trustedDomains = [
            "zoom.us",
            "meet.google.com",
            "teams.microsoft.com",
            "webex.com",
            "gotomeeting.com",
            "whereby.com",
            "discord.gg",
            "discord.com"
        ]

        // Check if host matches or is subdomain of trusted domains
        for domain in trustedDomains {
            if host == domain || host.hasSuffix(".\(domain)") {
                return true
            }
        }

        return false
    }

    private func timeUntilEvent(_ date: Date) -> String {
        let interval = date.timeIntervalSince(Date())
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "Starts in \(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "Starts in \(minutes)m"
        } else {
            return "Starting now"
        }
    }

    private func openClaudeWithMeetingContext() {
        // Sanitize inputs to prevent injection
        let meetingTitle = sanitizeForURL(event.title ?? "Untitled Event")
        let meetingTime = Self.dateFormatter.string(from: event.startDate)

        var prompt = """
        I have an upcoming meeting and need your help preparing for it. Please search my Gmail and Google Drive for relevant information.

        Meeting Details:
        - Title: \(meetingTitle)
        - Date/Time: \(meetingTime)
        """

        if let location = event.location, !location.isEmpty {
            let sanitizedLocation = sanitizeForURL(location)
            prompt += "\n- Location: \(sanitizedLocation)"
        }

        if let notes = event.notes, !notes.isEmpty {
            // Limit notes length and sanitize
            let limitedNotes = String(notes.prefix(500))
            let sanitizedNotes = sanitizeForURL(limitedNotes)
            prompt += "\n- Notes: \(sanitizedNotes)"
        }

        prompt += """


        Please help me with:
        1. Search my Gmail for recent emails about this meeting or topic
        2. Find relevant documents in my Google Drive
        3. Provide a brief summary of key context I should know
        4. Suggest any preparation steps or documents I should review

        """

        // URL encode the prompt with length validation
        guard prompt.count < 2000,
              let encodedPrompt = prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://claude.ai/new?q=\(encodedPrompt)"),
              encodedPrompt.count < 8000 else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func sanitizeForURL(_ input: String) -> String {
        // Remove potentially dangerous characters and limit length
        let allowed = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: ".,!?-:;()@"))

        return input.unicodeScalars
            .filter { allowed.contains($0) }
            .map { String($0) }
            .joined()
    }
}

// MARK: - Event Context Menu
struct EventContextMenu: View {
    let event: EKEvent

    private var meetingURL: URL? {
        extractMeetingURL(from: event)
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

    private func extractMeetingURL(from event: EKEvent) -> URL? {
        let patterns = [
            "https://[a-zA-Z0-9.-]+\\.zoom\\.us/j/[0-9]+",
            "https://meet\\.google\\.com/[a-z-]+",
            "https://teams\\.microsoft\\.com/l/meetup-join/[^\\s]+",
            "https://[a-zA-Z0-9.-]+\\.webex\\.com/[^\\s]+",
            "https://[a-zA-Z0-9.-]+\\.gotomeeting\\.com/[^\\s]+",
            "https://whereby\\.com/[a-z0-9-]+",
            "https://discord\\.gg/[a-zA-Z0-9]+",
            "https://discord\\.com/[^\\s]+"
        ]

        if let notes = event.notes?.prefix(2000) {
            if let url = findURLInText(String(notes), patterns: patterns) {
                return url
            }
        }

        if let location = event.location?.prefix(500) {
            if let url = findURLInText(String(location), patterns: patterns) {
                return url
            }
        }

        if let url = event.url, isURLSafe(url) {
            return url
        }

        return nil
    }

    private func findURLInText(_ text: String, patterns: [String]) -> URL? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                continue
            }

            if let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                let urlString = String(text[range])
                if let url = URL(string: urlString), isURLSafe(url) {
                    return url
                }
            }
        }
        return nil
    }

    private func isURLSafe(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" else {
            return false
        }

        guard let host = url.host?.lowercased() else {
            return false
        }

        let trustedDomains = [
            "zoom.us",
            "meet.google.com",
            "teams.microsoft.com",
            "webex.com",
            "gotomeeting.com",
            "whereby.com",
            "discord.gg",
            "discord.com"
        ]

        for domain in trustedDomains {
            if host == domain || host.hasSuffix(".\(domain)") {
                return true
            }
        }

        return false
    }
}
