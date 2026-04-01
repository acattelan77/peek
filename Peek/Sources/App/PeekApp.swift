import SwiftUI
import AppKit
import Combine
import Carbon
import EventKit

@main
struct PeekApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    // Constants
    private static let kHotKeyID: UInt32 = 1
    private static let kUpdateInterval = StatusBarRefreshPolicy.normalInterval

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var calendarManager: CalendarManager!
    private var cancellables = Set<AnyCancellable>()
    private var hotKeyRef: EventHotKeyRef?
    private var updateTimer: Timer?
    private let notificationManager = NotificationManager.shared
    private var pulseTimer: Timer?
    private var isPulsing = false
    private var isShowingIconOnlyForSpace = false
    private var outsideClickEventMonitor: Any?
    private var refreshWorkItem: DispatchWorkItem?
    private var lastScheduledEventSignature: [String] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize calendar manager
        calendarManager = CalendarManager()

        // Create status item in menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Set the menu bar icon
            if let icon = NSImage(named: "StatusBarIcon") {
                icon.isTemplate = true // Enable template rendering for dark mode support
                button.image = icon
                button.imagePosition = .imageLeading // Icon on the left, text on the right
            }

            // Improve vertical alignment
            button.imageHugsTitle = true

            // Set font to match system menu bar font for proper alignment
            button.font = NSFont.menuBarFont(ofSize: 0)

            button.title = NSLocalizedString("Loading...", comment: "Status bar initial loading title")
            button.action = #selector(togglePopover)
            button.target = self

            // Enable Cmd+drag to reposition
            button.sendAction(on: [.leftMouseUp, .leftMouseDown, .leftMouseDragged])
        }

        // Create popover
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        let menuBarView = MenuBarView(
            calendarManager: calendarManager,
            closePopover: { [weak self] in
                self?.popover.performClose(nil)
            },
            refreshStatusBar: { [weak self] event in
                self?.applyMenuBar(event: event)
            }
        )

        popover.contentViewController = NSHostingController(rootView: menuBarView)

        // Observe changes to enabled calendars and refresh when changed
        calendarManager.$enabledCalendarIDs
            .dropFirst()
            .sink { [weak self] _ in
                self?.scheduleRefresh(debounce: 0.05)
            }
            .store(in: &cancellables)

        calendarManager.$lookaheadDays
            .dropFirst()
            .sink { [weak self] _ in
                self?.scheduleRefresh(debounce: 0.05)
            }
            .store(in: &cancellables)

        calendarManager.$maxEventsToShow
            .dropFirst()
            .sink { [weak self] _ in
                self?.scheduleRefresh(debounce: 0.05)
            }
            .store(in: &cancellables)

        calendarManager.$hideAllDayEvents
            .dropFirst()
            .sink { [weak self] _ in
                self?.scheduleRefresh(debounce: 0.05)
            }
            .store(in: &cancellables)

        calendarManager.$hideDeclinedEvents
            .dropFirst()
            .sink { [weak self] _ in
                self?.scheduleRefresh(debounce: 0.05)
            }
            .store(in: &cancellables)

        calendarManager.$filterKeywords
            .dropFirst()
            .sink { [weak self] _ in
                self?.scheduleRefresh(debounce: 0.25)
            }
            .store(in: &cancellables)

        // Observe status bar display mode changes
        calendarManager.$statusBarMode
            .sink { [weak self] _ in
                self?.updateMenuBar()
            }
            .store(in: &cancellables)

        calendarManager.$showEventCount
            .sink { [weak self] _ in
                self?.updateMenuBar()
            }
            .store(in: &cancellables)

        calendarManager.$urgencyColorsEnabled
            .sink { [weak self] _ in
                self?.updateMenuBar()
            }
            .store(in: &cancellables)

        // Observe notification settings changes
        calendarManager.$notificationsEnabled
            .sink { [weak self] isEnabled in
                guard let self = self else { return }
                if isEnabled {
                    self.notificationManager.checkPermission { granted in
                        if granted {
                            self.maybeRescheduleNotifications(force: true)
                        } else {
                            self.notificationManager.requestPermission { permissionGranted in
                                if permissionGranted {
                                    self.maybeRescheduleNotifications(force: true)
                                } else {
                                    DispatchQueue.main.async {
                                        self.calendarManager.notificationsEnabled = false
                                    }
                                }
                            }
                        }
                    }
                } else {
                    self.maybeRescheduleNotifications(force: true)
                }
            }
            .store(in: &cancellables)

        calendarManager.$notificationTiming
            .sink { [weak self] _ in
                self?.maybeRescheduleNotifications(force: true)
            }
            .store(in: &cancellables)

        // Register global hotkey (Cmd+Shift+C)
        registerGlobalHotkey()

        // Observe app activation to refresh permissions and events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        // Observe EventKit changes to refresh UI and notifications
        calendarManager.startObservingChanges { [weak self] in
            self?.scheduleRefresh(debounce: 1.0)
        }

        // Request calendar access and start monitoring
        calendarManager.requestAccess { [weak self] granted, error in
            if granted {
                self?.handleCalendarAccessChange(granted: true, shouldRefresh: true)

                // Request notification permissions if notifications are enabled
                self?.notificationManager.requestPermission { notificationGranted in
                    if notificationGranted {
                        self?.rescheduleNotifications()
                    }
                }
            } else {
                if let error = error {
                    print("Calendar access error: \(error.localizedDescription)")
                }
                DispatchQueue.main.async {
                    self?.handleCalendarAccessChange(granted: false, shouldRefresh: false)
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        unregisterGlobalHotkey()
        updateTimer?.invalidate()
        updateTimer = nil
        pulseTimer?.invalidate()
        pulseTimer = nil

        if let monitor = outsideClickEventMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickEventMonitor = nil
        }

        calendarManager.stopObservingChanges()

    }

    @objc private func handleAppDidBecomeActive() {
        let granted = calendarManager.refreshAuthorizationStatus()
        handleCalendarAccessChange(granted: granted, shouldRefresh: true)
    }

    private func handleCalendarAccessChange(granted: Bool, shouldRefresh: Bool) {
        if granted {
            if updateTimer == nil {
                startTimer()
            }
            if shouldRefresh {
                scheduleRefresh(debounce: 0.1)
            }
        } else {
            updateTimer?.invalidate()
            updateTimer = nil
            showNoCalendarAccess()
            notificationManager.clearAllPendingNotifications()
        }
    }

    private func scheduleRefresh(debounce: TimeInterval) {
        refreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.updateMenuBar()
        }
        refreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + debounce, execute: workItem)
    }

    private func showNoCalendarAccess() {
        if let button = statusItem.button {
            let title = NSLocalizedString("No Calendar Access", comment: "Status bar title when calendar access denied")
            let tooltip = NSLocalizedString(
                "Grant permission in System Settings → Privacy & Security → Calendars",
                comment: "Tooltip when calendar access denied"
            )
            button.title = title
            button.toolTip = tooltip
            applyMenuBarSpaceConstraintIfNeeded(
                button: button,
                title: title,
                tooltip: tooltip,
                urgency: .normal
            )
        }
    }

    private func registerGlobalHotkey() {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType("PEEK".fourCharCodeValue)
        hotKeyID.id = Self.kHotKeyID

        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)

        // Get hotkey configuration from CalendarManager
        let hotkey = calendarManager.globalHotkey
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            print("Failed to register global hotkey")
        }

        // Install event handler
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, userData in
            let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData!).takeUnretainedValue()
            appDelegate.togglePopover()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    private func unregisterGlobalHotkey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }

        if let event = NSApp.currentEvent {
            if event.type == .leftMouseDragged {
                return
            }

            if event.type == .leftMouseDown {
                // Allow the system to handle Cmd+drag for repositioning
                if event.modifierFlags.contains(.command) {
                    return
                }
                // Ignore mouse down to avoid double-toggle with mouse up
                return
            }
        }

        if popover.isShown {
            if let monitor = outsideClickEventMonitor {
                NSEvent.removeMonitor(monitor)
                outsideClickEventMonitor = nil
            }
            popover.performClose(nil)
        } else {
            // Toggle urgency colors only when SHOWING the popover
            calendarManager.urgencyColorsEnabled.toggle()
            calendarManager.savePreferences()

            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

            // Make sure to remove any existing monitor before creating a new one to prevent leaks
            if let monitor = outsideClickEventMonitor {
                NSEvent.removeMonitor(monitor)
                outsideClickEventMonitor = nil
            }

            // Install a global event monitor to close popover when clicking outside
            outsideClickEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self = self else { return }
                // If the popover is not shown, remove monitor and return
                guard self.popover.isShown else {
                    if let monitor = self.outsideClickEventMonitor {
                        NSEvent.removeMonitor(monitor)
                        self.outsideClickEventMonitor = nil
                    }
                    return
                }
                // Determine the window under the mouse click; if it's not the popover's, close it
                if let clickedWindow = NSApp.window(withWindowNumber: event.windowNumber) {
                    if clickedWindow != self.popover.contentViewController?.view.window {
                        self.popover.performClose(nil)
                    }
                } else {
                    // Click on desktop or non-window area
                    self.popover.performClose(nil)
                }
            }
        }
    }

    private func updateMenuBar() {
        calendarManager.fetchNextEvent { [weak self] event in
            self?.applyMenuBar(event: event)
        }
    }

    private func applyMenuBar(event: EKEvent?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let button = self.statusItem.button {
                let eventCount = self.calendarManager.upcomingEvents.count

                if let event = event, eventCount > 0 {
                    var displayCount = eventCount
                    if let index = self.calendarManager.upcomingEvents.firstIndex(where: { $0.eventIdentifier == event.eventIdentifier }) {
                        displayCount = eventCount - index
                    }

                    let (title, tooltip, urgency) = self.formatStatusBarText(event: event, eventCount: displayCount)

                    // Set title and tooltip first
                    button.title = title
                    button.toolTip = tooltip

                    // Apply color based on urgency (AFTER setting title)
                    self.applyUrgencyStyle(to: button, urgency: urgency)

                    // Handle pulsing animation for imminent meetings
                    self.updatePulsingState(urgency: urgency)

                    // Adjust timer frequency based on urgency
                    self.adjustTimerForUrgency(urgency)

                    // Fall back to icon-only if the menu bar is cramped
                    self.applyMenuBarSpaceConstraintIfNeeded(
                        button: button,
                        title: title,
                        tooltip: tooltip,
                        urgency: urgency
                    )
                } else {
                    let title = self.calendarManager.statusBarMode == .iconOnly
                        ? ""
                        : NSLocalizedString("No upcoming events", comment: "Status bar title when no events")
                    button.title = title
                    button.toolTip = nil
                    button.attributedTitle = NSAttributedString(string: button.title)
                    self.stopPulsing()
                    self.adjustTimerForUrgency(.normal)
                    self.applyMenuBarSpaceConstraintIfNeeded(
                        button: button,
                        title: title,
                        tooltip: nil,
                        urgency: .normal
                    )
                }
            }

            self.maybeRescheduleNotifications(force: false)
        }
    }

    private func applyUrgencyStyle(to button: NSStatusBarButton, urgency: MeetingUrgency) {
        let titleString = button.title
        let attributedString = NSMutableAttributedString(string: titleString)

        // Set color based on urgency (only if colors are enabled)
        let color: NSColor
        if calendarManager.urgencyColorsEnabled {
            switch urgency {
            case .critical:
                color = .systemRed
            case .urgent:
                color = .systemOrange
            case .normal:
                color = .labelColor // System default
            }
        } else {
            color = .labelColor // System default when disabled
        }

        // Apply color to the entire string
        attributedString.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: attributedString.length))

        // Use system menu bar font for proper alignment
        let font = NSFont.menuBarFont(ofSize: 0)
        attributedString.addAttribute(.font, value: font, range: NSRange(location: 0, length: attributedString.length))

        button.attributedTitle = attributedString
    }

    private func updatePulsingState(urgency: MeetingUrgency) {
        if urgency == .critical && calendarManager.urgencyColorsEnabled {
            startPulsing()
        } else {
            stopPulsing()
        }
    }

    private func startPulsing() {
        guard !isPulsing else { return }
        isPulsing = true

        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, let button = self.statusItem.button else { return }

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.5
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                button.animator().alphaValue = button.alphaValue == 1.0 ? 0.3 : 1.0
            })
        }
    }

    private func stopPulsing() {
        guard isPulsing else { return }
        isPulsing = false

        pulseTimer?.invalidate()
        pulseTimer = nil

        // Reset alpha
        if let button = statusItem.button {
            button.alphaValue = 1.0
        }
    }

    private func adjustTimerForUrgency(_ urgency: MeetingUrgency) {
        let newInterval = StatusBarRefreshPolicy.interval(for: urgency)
        if updateTimer?.timeInterval != newInterval {
            startTimer(interval: newInterval)
        }
    }

    private func rescheduleNotifications() {
        guard calendarManager.notificationsEnabled else {
            // Clear all pending notifications if disabled
            notificationManager.clearAllPendingNotifications()
            return
        }

        let eventsToSchedule = calendarManager.allUpcomingEvents.isEmpty
            ? calendarManager.upcomingEvents
            : calendarManager.allUpcomingEvents

        notificationManager.scheduleNotifications(
            for: eventsToSchedule,
            timing: calendarManager.notificationTiming
        )
    }

    private func currentNotificationEventSignature() -> [String] {
        let events = calendarManager.allUpcomingEvents.isEmpty
            ? calendarManager.upcomingEvents
            : calendarManager.allUpcomingEvents

        return events.compactMap(NotificationContentSignature.make(for:))
    }

    private func maybeRescheduleNotifications(force: Bool) {
        if !force && !calendarManager.notificationsEnabled {
            return
        }
        let signature = currentNotificationEventSignature()
        if force || signature != lastScheduledEventSignature {
            lastScheduledEventSignature = signature
            rescheduleNotifications()
        }
    }

    private func formatStatusBarText(event: EKEvent, eventCount: Int) -> (String, String?, MeetingUrgency) {
        let mode = calendarManager.statusBarMode
        let showCount = calendarManager.showEventCount

        let now = Date()
        let minutesUntil = Int(event.startDate.timeIntervalSince(now)) / 60

        // Calculate urgency level
        let urgency = MeetingUrgency.from(minutesUntil: minutesUntil)

        // Icon only mode
        if mode == .iconOnly {
            let tooltipTitle = event.title ?? NSLocalizedString("Untitled Event", comment: "Fallback event title")
            return ("", tooltipTitle, urgency)
        }

        let eventTitle = event.title ?? NSLocalizedString("Untitled Event", comment: "Fallback event title")
        let maxTitleLength = 20
        let truncatedTitle = eventTitle.count > maxTitleLength
            ? String(eventTitle.prefix(maxTitleLength)) + "..."
            : eventTitle

        let countSuffix = (eventCount > 1 && showCount)
            ? String(
                format: NSLocalizedString(" (+%d)", comment: "Suffix showing additional event count"),
                eventCount - 1
            )
            : ""

        var timeString: String

        if mode == .timeUntil {
            // Time until mode
            if event.startDate > now {
                let interval = event.startDate.timeIntervalSince(now)
                let hours = Int(interval) / 3600
                let minutes = (Int(interval) % 3600) / 60

                if hours > 24 {
                    let days = hours / 24
                    let format = NSLocalizedString("%dd", comment: "Abbreviated days")
                    timeString = String(format: format, days)
                } else if hours > 0 {
                    let format = NSLocalizedString("%dh %dm", comment: "Abbreviated hours and minutes")
                    timeString = String(format: format, hours, minutes)
                } else if minutes > 0 {
                    let format = NSLocalizedString("%dm", comment: "Abbreviated minutes")
                    timeString = String(format: format, minutes)
                } else {
                    timeString = NSLocalizedString("NOW!", comment: "Status bar label when event is now")
                }
            } else {
                timeString = NSLocalizedString("NOW!", comment: "Status bar label when event is now")
            }
        } else {
            // Actual time mode
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            timeString = formatter.string(from: event.startDate)
        }

        let titleFormat = NSLocalizedString("%@ - %@%@", comment: "Status bar title format: time - title (+count)")
        let title = String(format: titleFormat, timeString, truncatedTitle, countSuffix)
        let tooltip = eventTitle.count > maxTitleLength
            ? String(format: NSLocalizedString("%@ - %@", comment: "Status bar tooltip format: time - title"), timeString, eventTitle)
            : nil

        return (title, tooltip, urgency)
    }

    private func startTimer(interval: TimeInterval = kUpdateInterval) {
        // Invalidate existing timer if any
        updateTimer?.invalidate()

        // Update with specified interval
        updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateMenuBar()
        }
    }

    private func applyMenuBarSpaceConstraintIfNeeded(
        button: NSStatusBarButton,
        title: String,
        tooltip: String?,
        urgency: MeetingUrgency
    ) {
        if calendarManager.statusBarMode == .iconOnly {
            isShowingIconOnlyForSpace = false
            if button.imagePosition != .imageOnly {
                button.imagePosition = .imageOnly
            }
            return
        }

        let shouldForceIconOnly = shouldForceIconOnly(button: button, title: title)

        if shouldForceIconOnly {
            isShowingIconOnlyForSpace = true
            if button.imagePosition != .imageOnly {
                button.imagePosition = .imageOnly
            }
            if !title.isEmpty {
                button.title = ""
                button.attributedTitle = NSAttributedString(string: "")
            }
            button.toolTip = tooltip ?? title
        } else {
            if button.imagePosition != .imageLeading {
                button.imagePosition = .imageLeading
            }
            if isShowingIconOnlyForSpace {
                isShowingIconOnlyForSpace = false
                button.title = title
                button.toolTip = tooltip
                applyUrgencyStyle(to: button, urgency: urgency)
            }
        }
    }

    private func shouldForceIconOnly(button: NSStatusBarButton, title: String) -> Bool {
        guard !title.isEmpty else { return false }
        guard button.bounds.width > 0 else { return false }

        let font = button.font ?? NSFont.menuBarFont(ofSize: 0)
        let titleWidth = (title as NSString).size(withAttributes: [.font: font]).width

        let previousImagePosition = button.imagePosition
        button.imagePosition = .imageLeading
        let titleRect = (button.cell as? NSButtonCell)?.titleRect(forBounds: button.bounds) ?? button.bounds
        button.imagePosition = previousImagePosition

        return titleWidth - titleRect.width > 2
    }
}

extension String {
    var fourCharCodeValue: FourCharCode {
        var result: FourCharCode = 0
        if let data = self.data(using: .macOSRoman) {
            data.withUnsafeBytes { bytes in
                let pointer = bytes.bindMemory(to: UInt8.self)
                for i in 0..<min(4, data.count) {
                    result = result << 8 + FourCharCode(pointer[i])
                }
            }
        }
        return result
    }
}
