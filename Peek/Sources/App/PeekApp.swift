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
    private static let kUpdateInterval = StatusBarRefreshPolicy.normalInterval

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var environment: AppEnvironment!
    private var calendarManager: CalendarManager!
    private var cancellables = Set<AnyCancellable>()
    private var hotkeyRegistrar: CarbonHotkeyRegistrar!
    private var updateTimer: Timer?
    private var notificationManager: (any NotificationScheduling)!
    private var pulseTimer: Timer?
    private var isPulsing = false
    private var spacePolicy: StatusBarSpacePolicy!
    private var outsideClickEventMonitor: Any?
    private var refreshWorkItem: DispatchWorkItem?
    private var lastScheduledEventSignature: [String] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Compose live infrastructure once, at the application boundary.
        environment = .live()
        calendarManager = environment.calendarManager
        notificationManager = environment.notificationScheduler
        spacePolicy = StatusBarSpacePolicy(policy: calendarManager.menuBarSpacePolicy)

        // Own the Carbon hotkey lifecycle in a focused registrar so it can be
        // re-applied live and its Carbon event handler is installed exactly once.
        hotkeyRegistrar = CarbonHotkeyRegistrar { [weak self] in
            self?.handleHotkeyPressed()
        }

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

        // Observe menu-bar space policy changes
        calendarManager.$menuBarSpacePolicy
            .sink { [weak self] policy in
                self?.spacePolicy = StatusBarSpacePolicy(policy: policy)
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

        // Re-register the global hotkey live whenever the user changes it.
        calendarManager.$globalHotkey
            .dropFirst()
            .sink { [weak self] hotkey in
                self?.applyGlobalHotkey(hotkey)
            }
            .store(in: &cancellables)

        // Register the initial global hotkey.
        applyGlobalHotkey(calendarManager.globalHotkey)

        // Observe app activation to refresh permissions and events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        // Observe display configuration changes so the space policy can re-evaluate
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
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

                if self?.calendarManager.notificationsEnabled == true {
                    self?.notificationManager.requestPermission { notificationGranted in
                        if notificationGranted {
                            self?.rescheduleNotifications()
                        }
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
        hotkeyRegistrar?.unregister()
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

    @objc private func handleScreenParametersChanged() {
        scheduleRefresh(debounce: 0.1)
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
            applyStatusBarContent(
                button: button,
                content: StatusBarContent(title: title, tooltip: tooltip, urgency: .normal)
            )
        }
    }

    /// Applies the user's hotkey selection through the testable coordinator and
    /// publishes any registration failure so Preferences can show it.
    private func applyGlobalHotkey(_ hotkey: HotkeyOption) {
        let result = GlobalHotkeyCoordinator.apply(hotkey, using: hotkeyRegistrar)
        calendarManager.hotkeyStatusMessage = result.errorMessage
        if let message = result.errorMessage {
            print(message)
        }
    }

    /// Invoked from the Carbon hotkey handler. Bring Peek forward so the popover is
    /// presented above the frontmost app, then toggle it.
    private func handleHotkeyPressed() {
        NSApp.activate(ignoringOtherApps: true)
        togglePopover()
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
            guard let button = self.statusItem.button else {
                self.maybeRescheduleNotifications(force: false)
                return
            }

            let eventCount = self.calendarManager.upcomingEvents.count
            let content: StatusBarContent

            if let event = event, eventCount > 0 {
                var displayCount = eventCount
                if let index = self.calendarManager.upcomingEvents.firstIndex(where: { $0.eventIdentifier == event.eventIdentifier }) {
                    displayCount = eventCount - index
                }

                content = StatusBarContentBuilder.make(
                    eventTitle: event.title,
                    startDate: event.startDate,
                    eventCount: displayCount,
                    mode: self.calendarManager.statusBarMode,
                    showCount: self.calendarManager.showEventCount
                )

                self.updatePulsingState(urgency: content.urgency)
                self.adjustTimerForUrgency(content.urgency)
            } else {
                content = StatusBarContent(
                    title: NSLocalizedString("No upcoming events", comment: "Status bar title when no events"),
                    tooltip: nil,
                    urgency: .normal
                )
                self.stopPulsing()
                self.adjustTimerForUrgency(.normal)
            }

            self.applyStatusBarContent(button: button, content: content)
            self.maybeRescheduleNotifications(force: false)
        }
    }

    private func applyStatusBarContent(button: NSStatusBarButton, content: StatusBarContent) {
        // Prepare the full text presentation so it can be measured and used as a tooltip.
        button.title = content.title
        button.toolTip = content.tooltip
        applyUrgencyStyle(to: button, urgency: content.urgency)

        let metrics = statusItemMetrics(button: button, title: content.title)
        let presentation = spacePolicy.update(
            availableWidth: metrics.availableWidth,
            requiredWidth: metrics.requiredWidth,
            notchMargin: metrics.notchMargin
        )

        switch presentation {
        case .iconOnly:
            button.imagePosition = .imageOnly
            button.title = ""
            button.attributedTitle = NSAttributedString(string: "")
            button.toolTip = content.tooltip ?? content.title
        case .text:
            button.imagePosition = .imageLeading
        }

        button.setAccessibilityLabel(content.tooltip ?? content.title)
    }

    private func statusItemMetrics(button: NSStatusBarButton, title: String) -> (availableWidth: CGFloat, requiredWidth: CGFloat, notchMargin: CGFloat) {
        let window = button.window
        let screen = window?.screen ?? NSScreen.main
        let screenFrame = screen?.frame ?? .zero

        let availableWidth: CGFloat
        if let window = window {
            availableWidth = max(0, screenFrame.maxX - window.frame.minX)
        } else {
            availableWidth = screenFrame.width
        }

        let iconWidth = button.image?.size.width ?? 0
        let font = button.font ?? NSFont.menuBarFont(ofSize: 0)
        let titleWidth = (title as NSString).size(withAttributes: [.font: font]).width
        let requiredWidth = iconWidth + titleWidth + 12

        let notchMargin: CGFloat = (screen?.safeAreaInsets.top ?? 0) > 0 ? 60 : 0

        return (availableWidth, requiredWidth, notchMargin)
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

    private func startTimer(interval: TimeInterval = kUpdateInterval) {
        // Invalidate existing timer if any
        updateTimer?.invalidate()

        // Update with specified interval
        updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateMenuBar()
        }
    }

}

/// Live Carbon implementation of `HotkeyRegistering`. Installs the hot-key event
/// handler once at construction and re-registers the key combination on demand,
/// unregistering any previous binding first. This is the only place that touches
/// Carbon's hot-key API.
final class CarbonHotkeyRegistrar: HotkeyRegistering {
    private static let hotKeyID: UInt32 = 1

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let handler: () -> Void
    private let signature = OSType("PEEK".fourCharCodeValue)

    init(handler: @escaping () -> Void) {
        self.handler = handler
        installEventHandler()
    }

    deinit {
        unregister()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let registrar = Unmanaged<CarbonHotkeyRegistrar>.fromOpaque(userData).takeUnretainedValue()
                registrar.handler()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }

    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32) -> OSStatus {
        unregister()
        let hotKeyID = EventHotKeyID(signature: signature, id: Self.hotKeyID)
        return RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
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
