import SwiftUI
import AppKit
import Combine
import EventKit

@main
struct PeekApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // XCTest launches the host application with runner-owned arguments. They
        // are not user CLI input and must not trigger the headless command path.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }
        let arguments = Array(CommandLine.arguments.dropFirst())
        // LaunchServices may add this process-serial-number argument when the
        // app is opened normally from Finder or the Dock.
        guard !arguments.contains(where: { $0.hasPrefix("-psn_") }) else {
            return
        }
        switch CalendarExportCommandLine.parse(arguments: arguments) {
        case .notRequested:
            break
        case .command(.help):
            FileHandle.standardOutput.write(Data((CalendarExportCommandLine.usage + "\n").utf8))
            exit(EXIT_SUCCESS)
        case let .command(.export(request)):
            switch CalendarExportRunner.execute(request) {
            case let .success(data):
                FileHandle.standardOutput.write(data)
                FileHandle.standardOutput.write(Data("\n".utf8))
                exit(EXIT_SUCCESS)
            case let .failure(error):
                FileHandle.standardError.write(Data("Peek export error: \(error.localizedDescription)\n".utf8))
                exit(EXIT_FAILURE)
            }
        case let .failure(message):
            FileHandle.standardError.write(Data("Peek export error: \(message)\n".utf8))
            exit(EXIT_FAILURE)
        }
    }

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
    private var joinHotkeyRegistrar: CarbonHotkeyRegistrar!
    private var discreetHotkeyRegistrar: CarbonHotkeyRegistrar!
    private let discreetMode = DiscreetModeController.shared
    /// The calendar glyph; `statusGlyph` swaps to the eye while discreet (PEEK-274).
    private var calendarGlyph: NSImage?
    private var lastDiscreetState = false
    private var updateTimer: Timer?
    private var notificationManager: (any NotificationScheduling)!
    private var pulseTimer: Timer?
    private var isPulsing = false
    private var spacePolicy: StatusBarSpacePolicy!
    /// The template glyph shown beside plain titles; pills draw a tinted copy.
    private var statusGlyph: NSImage?
    private var statusItemWindowState: StatusBarItemWindowState = .notYetLaidOut
    private var collapsedWhileHidden = false
    private var outsideClickEventMonitor: Any?
    private var isPopoverPresentationPending = false
    private let popoverAnchorController = PopoverAnchorController()
    private let hudController = StartingNowHUDController()
    private var refreshWorkItem: DispatchWorkItem?
    private var notificationRetryWorkItem: DispatchWorkItem?
    private var lastScheduledEventSignature: [String] = []
    private let systemTimeObserver: any SystemTimeObserving = SystemTimeObserver()
    /// Set by a wake or a clock change: the next refresh reschedules every
    /// notification even if the events did not change (PEEK-271).
    private var forceNotificationRescheduleOnRefresh = false
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Compose live infrastructure once, at the application boundary.
        environment = .live()
        let launchVersion = AppVersion.from()
        Diagnostics.record(.appLaunched(
            version: launchVersion.marketingVersion,
            build: launchVersion.buildNumber,
            system: ProcessInfo.processInfo.operatingSystemVersionString
        ))
        MetricKitCollector.shared.start()
        calendarManager = environment.calendarManager
        notificationManager = environment.notificationScheduler
        spacePolicy = StatusBarSpacePolicy(policy: calendarManager.menuBarSpacePolicy)

        // Own the Carbon hotkey lifecycle in a focused registrar so it can be
        // re-applied live and its Carbon event handler is installed exactly once.
        hotkeyRegistrar = CarbonHotkeyRegistrar { [weak self] in
            self?.handleHotkeyPressed()
        }
        joinHotkeyRegistrar = CarbonHotkeyRegistrar(id: 2) { [weak self] in
            self?.joinNextMeeting()
        }
        discreetHotkeyRegistrar = CarbonHotkeyRegistrar(id: 3) { [weak self] in
            self?.discreetMode.toggle()
        }

        // Create status item in menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Set the menu bar icon
            if let icon = NSImage(named: "StatusBarIcon") {
                icon.isTemplate = true // Enable template rendering for dark mode support
                calendarGlyph = icon
                statusGlyph = icon
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
        popover.delegate = self

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
                self?.collapsedWhileHidden = false
                self?.updateMenuBar()
            }
            .store(in: &cancellables)

        calendarManager.$urgencyColorsEnabled
            .sink { [weak self] _ in
                self?.updateMenuBar()
            }
            .store(in: &cancellables)

        // Badge-only calendars change which events may notify.
        calendarManager.$badgeOnlyCalendarIDs
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.maybeRescheduleNotifications(force: true)
                }
            }
            .store(in: &cancellables)

        // Muting or hiding one event changes what is listed and what may
        // notify (PEEK-273).
        calendarManager.$eventOverrides
            .dropFirst()
            .sink { [weak self] _ in
                self?.scheduleRefresh(debounce: 0.05)
                DispatchQueue.main.async {
                    self?.maybeRescheduleNotifications(force: true)
                }
            }
            .store(in: &cancellables)

        // Observe notification settings changes
        calendarManager.$notificationsEnabled
            .sink { [weak self] isEnabled in
                guard let self = self else { return }
                if isEnabled {
                    self.notificationManager.checkPermission { granted in
                        if granted {
                            self.calendarManager.notificationStatusMessage = nil
                            self.maybeRescheduleNotifications(force: true)
                        } else {
                            self.notificationManager.requestPermission { permissionGranted in
                                if permissionGranted {
                                    self.calendarManager.notificationStatusMessage = nil
                                    self.maybeRescheduleNotifications(force: true)
                                } else {
                                    self.notificationManager.clearAllPendingNotifications()
                                    self.calendarManager.notificationStatusMessage = NotificationSchedulingFeedback.message(for: .authorizationRequired)
                                }
                            }
                        }
                    }
                } else {
                    self.notificationRetryWorkItem?.cancel()
                    self.notificationRetryWorkItem = nil
                    self.calendarManager.notificationStatusMessage = nil
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

        calendarManager.$joinHotkey
            .sink { [weak self] hotkey in
                guard let self else { return }
                let result = GlobalHotkeyCoordinator.apply(hotkey, using: self.joinHotkeyRegistrar)
                self.calendarManager.joinHotkeyStatusMessage = result.errorMessage
                if result.errorMessage != nil {
                    Diagnostics.record(.hotkeyRegistrationFailed(shortcut: hotkey.rawValue))
                }
            }
            .store(in: &cancellables)

        // Discreet mode (PEEK-274): its shortcut, and the menu bar follows it.
        discreetMode.$hotkey
            .sink { [weak self] hotkey in
                guard let self else { return }
                let result = GlobalHotkeyCoordinator.apply(hotkey, using: self.discreetHotkeyRegistrar)
                self.discreetMode.hotkeyStatusMessage = result.errorMessage
            }
            .store(in: &cancellables)

        discreetMode.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.discreetMode.isActive != self.lastDiscreetState else { return }
                self.lastDiscreetState = self.discreetMode.isActive
                self.applyDiscreetGlyph()
                if self.calendarManager.hasCalendarAccess {
                    self.updateMenuBar()
                }
            }
            .store(in: &cancellables)
        lastDiscreetState = discreetMode.isActive
        applyDiscreetGlyph()

        calendarManager.$statusBarOnlyMeetings
            .dropFirst()
            .sink { [weak self] _ in
                self?.updateMenuBar()
            }
            .store(in: &cancellables)

        calendarManager.$statusBarLabelStyle
            .dropFirst()
            .sink { [weak self] _ in
                self?.updateMenuBar()
            }
            .store(in: &cancellables)

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

        // Wake, time zone, clock and day changes move every alert time (PEEK-271).
        systemTimeObserver.start { [weak self] changes in
            self?.handleSystemTimeChanges(changes)
        }

        // First run shows onboarding, which drives calendar access itself. Existing
        // users (already authorized, or previously onboarded) skip straight to the
        // normal access flow.
        let alreadyAuthorized = calendarManager.refreshAuthorizationStatus()
        if calendarManager.hasCompletedOnboarding || alreadyAuthorized {
            requestCalendarAccessAndStart()
        } else {
            presentOnboarding()
        }
    }

    /// Requests calendar access and begins monitoring. Safe to call when already
    /// authorized (the system returns the cached decision without re-prompting).
    private func requestCalendarAccessAndStart() {
        calendarManager.requestAccess { [weak self] granted, error in
            Diagnostics.record(.calendarAccess(granted: granted, errorCode: (error as NSError?)?.code))
            if granted {
                self?.handleCalendarAccessChange(granted: true, shouldRefresh: true)

                if self?.calendarManager.notificationsEnabled == true {
                    self?.notificationManager.requestPermission { notificationGranted in
                        if notificationGranted {
                            self?.rescheduleNotifications(reason: .permission)
                        } else {
                            self?.notificationManager.clearAllPendingNotifications()
                            self?.calendarManager.notificationStatusMessage = NotificationSchedulingFeedback.message(for: .authorizationRequired)
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self?.handleCalendarAccessChange(granted: false, shouldRefresh: false)
                }
            }
        }
    }

    // MARK: - Onboarding

    private func presentOnboarding() {
        let view = OnboardingView(calendarManager: calendarManager) { [weak self] in
            self?.finishOnboarding()
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.title = "Peek"
        window.delegate = self
        window.center()
        window.level = .floating
        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func finishOnboarding() {
        guard let window = onboardingWindow else { return }
        calendarManager.completeOnboarding()
        onboardingWindow = nil
        window.close()

        // Reflect whatever access state onboarding produced without a second prompt.
        let granted = calendarManager.refreshAuthorizationStatus()
        handleCalendarAccessChange(granted: granted, shouldRefresh: true)
        if granted && calendarManager.notificationsEnabled {
            notificationManager.requestPermission { [weak self] ok in
                if ok {
                    self?.rescheduleNotifications(reason: .permission)
                } else {
                    self?.notificationManager.clearAllPendingNotifications()
                    self?.calendarManager.notificationStatusMessage = NotificationSchedulingFeedback.message(for: .authorizationRequired)
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyRegistrar?.unregister()
        joinHotkeyRegistrar?.unregister()
        discreetHotkeyRegistrar?.unregister()
        updateTimer?.invalidate()
        updateTimer = nil
        pulseTimer?.invalidate()
        pulseTimer = nil
        notificationRetryWorkItem?.cancel()
        notificationRetryWorkItem = nil

        if let monitor = outsideClickEventMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickEventMonitor = nil
        }
        isPopoverPresentationPending = false
        popoverAnchorController.detach()

        calendarManager.stopObservingChanges()
        systemTimeObserver.stop()
        hudController.close()
    }

    /// After a wake or a time zone, clock or day change: refresh the events,
    /// reschedule every notification, update the menu bar and re-evaluate the
    /// card and start alert. A snooze that ran out during sleep fires now.
    private func handleSystemTimeChanges(_ changes: Set<SystemTimeChange>) {
        guard !changes.isEmpty else { return }
        forceNotificationRescheduleOnRefresh = true
        hudController.tick()
        guard calendarManager.hasCalendarAccess else { return }
        scheduleRefresh(debounce: 0.1)
    }

    @objc private func handleAppDidBecomeActive() {
        let granted = calendarManager.refreshAuthorizationStatus()
        handleCalendarAccessChange(granted: granted, shouldRefresh: true)
        guard granted, calendarManager.notificationsEnabled else { return }
        notificationManager.checkPermission { [weak self] notificationGranted in
            if notificationGranted {
                self?.maybeRescheduleNotifications(force: true)
            } else {
                self?.notificationManager.clearAllPendingNotifications()
                self?.calendarManager.notificationStatusMessage = NotificationSchedulingFeedback.message(for: .authorizationRequired)
            }
        }
    }

    @objc private func handleScreenParametersChanged() {
        // A display change may have freed or rearranged menu-bar space, so let
        // Automatic re-evaluate whether it can show text again.
        collapsedWhileHidden = false
        discreetMode.refreshSignals()
        scheduleRefresh(debounce: 0.1)
    }

    /// The menu-bar indicator of discreet mode: the eye replaces the calendar
    /// glyph, in the plain title and in the pills alike.
    private func applyDiscreetGlyph() {
        let glyph: NSImage?
        if discreetMode.isActive,
           let eye = NSImage(
               systemSymbolName: "eye.slash",
               accessibilityDescription: NSLocalizedString("Discreet mode is on", comment: "Menu bar: discreet mode indicator")
           )?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)) {
            eye.isTemplate = true
            glyph = eye
        } else {
            glyph = calendarGlyph
        }
        guard glyph !== statusGlyph else { return }
        statusGlyph = glyph
        statusItem?.button?.image = glyph
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
        if result.errorMessage != nil {
            Diagnostics.record(.hotkeyRegistrationFailed(shortcut: hotkey.rawValue))
        }
    }

    /// Invoked from the Carbon hotkey handler. Bring Peek forward so the popover is
    /// presented above the frontmost app, then toggle it.
    private func handleHotkeyPressed() {
        NSApp.activate(ignoringOtherApps: true)
        togglePopover()
    }

    /// The join shortcut (PEEK-231): opens the meeting `JoinTargetPolicy`
    /// picks, or shows the popover when no meeting with a link is near.
    private func joinNextMeeting() {
        let events = calendarManager.activeEvents
        let candidates = events.map {
            JoinCandidate(start: $0.startDate, end: $0.endDate, hasJoinLink: MeetingURLDetector.extract(from: $0) != nil)
        }
        if let index = JoinTargetPolicy.pick(candidates, now: Date()),
           let url = MeetingURLDetector.extract(from: events[index]) {
            MeetingLinkOpener.open(url)
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        if !popover.isShown {
            togglePopover()
        }
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }

        let clickDerivedButtonFrame: NSRect?
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

            clickDerivedButtonFrame = PopoverAnchorController.eventDerivedButtonScreenFrame(
                button: button,
                event: event
            )
        } else {
            clickDerivedButtonFrame = nil
        }

        if popover.isShown || isPopoverPresentationPending {
            isPopoverPresentationPending = false
            if let monitor = outsideClickEventMonitor {
                NSEvent.removeMonitor(monitor)
                outsideClickEventMonitor = nil
            }
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popoverAnchorController.detach()
            }
        } else {
            // As an accessory (LSUIElement) app, Peek is not activated by a status-item
            // click. Without activating, the popover's window never becomes key: its
            // controls render in the inactive (grey) appearance and the transient
            // popover is dismissed almost immediately. Activation can also rearrange
            // status items, so wait for the next layout pass before capturing the
            // button's position as the popover anchor.
            // Never change `statusItem.length` here (PEEK-283): on recent macOS the
            // status item is hosted by the system menu bar, and resizing it while
            // the click is delivered swallows the click. The anchor window keeps
            // the popover still on its own (`PopoverPresentationPolicy.anchorFrame`).
            isPopoverPresentationPending = true
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async { [weak self, weak button, clickDerivedButtonFrame] in
                guard let self = self, let button = button else { return }
                guard self.isPopoverPresentationPending, !self.popover.isShown else { return }
                self.isPopoverPresentationPending = false
                self.presentPopover(
                    relativeTo: button,
                    clickDerivedButtonFrame: clickDerivedButtonFrame
                )
            }
        }
    }

    private func presentPopover(
        relativeTo button: NSStatusBarButton,
        clickDerivedButtonFrame: NSRect?
    ) {
        guard popoverAnchorController.show(
            popover: popover,
            relativeTo: button,
            clickDerivedButtonFrame: clickDerivedButtonFrame
        ) else {
            return
        }
        popover.contentViewController?.view.window?.makeKey()
        installOutsideClickMonitor()
    }

    private func installOutsideClickMonitor() {
        if let monitor = outsideClickEventMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickEventMonitor = nil
        }

        outsideClickEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return }
            guard self.popover.isShown else {
                if let monitor = self.outsideClickEventMonitor {
                    NSEvent.removeMonitor(monitor)
                    self.outsideClickEventMonitor = nil
                }
                return
            }

            let popoverWindow = self.popover.contentViewController?.view.window
            if let clickedWindow = NSApp.window(withWindowNumber: event.windowNumber) {
                if clickedWindow != popoverWindow {
                    self.popover.performClose(nil)
                }
            } else {
                self.popover.performClose(nil)
            }
        }
    }

    private func updateMenuBar() {
        discreetMode.refreshSignals()
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
            let onlyMeetings = self.calendarManager.statusBarOnlyMeetings
            // The countdown may follow the next meeting with a link (PEEK-232);
            // the start alert and the brief always follow the next event.
            let displayEvent = event.flatMap { next in
                StatusBarEventChooser.pick(
                    next: next,
                    upcoming: self.calendarManager.allUpcomingEvents,
                    onlyMeetings: onlyMeetings,
                    hasJoinLink: { MeetingURLDetector.extract(from: $0) != nil }
                )
            }

            if let event = event, eventCount > 0 {
                MeetingBriefService.shared.prepareIfDue(for: event)
            }
            if let event = event, eventCount > 0,
               self.calendarManager.alerts(for: event) {
                let nextUrgency = MeetingUrgency.from(minutesUntil: Int(event.startDate.timeIntervalSince(Date())) / 60)
                self.hudController.maybeShow(
                    for: event,
                    urgency: nextUrgency,
                    appearanceMode: self.calendarManager.appearanceMode,
                    style: self.calendarManager.startAlertStyle,
                    interruptOnlyForMeetings: self.calendarManager.interruptOnlyForMeetings
                )
                self.hudController.maybeShowSoon(
                    for: event,
                    enabled: self.calendarManager.soonCardEnabled,
                    appearanceMode: self.calendarManager.appearanceMode,
                    interruptOnlyForMeetings: self.calendarManager.interruptOnlyForMeetings
                )
            } else if let event = event, eventCount > 0, !event.isAllDay,
                      (-60..<0).contains(event.startDate.timeIntervalSince(Date())) {
                // A badge-only calendar reached its start time: say why no alert showed.
                let ref = DiagnosticEventRef.make(identifier: event.eventIdentifier)
                Diagnostics.record(
                    .alertSkipped(kind: .startCard, reason: .badgeOnly, eventRef: ref),
                    throttleKey: "alert.badgeOnly.\(ref)",
                    minInterval: 3600
                )
            }

            // A running meeting takes the menu bar ("18 min left") while the
            // next event is still calm (Peek 2.0 menu bar states).
            let now = Date()
            let ongoing = self.calendarManager.activeEvents
                .filter { candidate in
                    !candidate.isAllDay
                        && candidate.startDate <= now
                        && candidate.endDate > now
                        && candidate.eventIdentifier != displayEvent?.eventIdentifier
                        && AppDelegate.isMeeting(candidate, requireJoinLink: onlyMeetings)
                }
                .min { $0.endDate < $1.endDate }
            let nextPhase = displayEvent.map {
                MenuBarPhase(urgency: MeetingUrgency.from(minutesUntil: Int($0.startDate.timeIntervalSince(now)) / 60))
            }

            if let running = ongoing,
               StatusBarContentBuilder.showsInProgress(nextPhase: eventCount > 0 ? nextPhase : nil, hasOngoingMeeting: true) {
                content = StatusBarContentBuilder.inProgress(title: running.title, endDate: running.endDate, now: now)
                self.stopPulsing()
                let nextUrgency = event.map { MeetingUrgency.from(minutesUntil: Int($0.startDate.timeIntervalSince(now)) / 60) } ?? .normal
                self.adjustTimerForUrgency(nextUrgency)
            } else if let shown = displayEvent, eventCount > 0 {
                let label: String?
                switch DiscreetModePolicy.labelStyle(self.calendarManager.statusBarLabelStyle, discreet: self.discreetMode.isActive) {
                case .eventTitle:
                    label = shown.title
                case .person:
                    label = MeetingContextProvider.context(for: shown).people.first?.shortName ?? shown.title
                }

                content = StatusBarContentBuilder.make(
                    eventTitle: label,
                    fullTitle: shown.title,
                    startDate: shown.startDate,
                    joinProvider: MeetingURLDetector.extract(from: shown).map { MeetingProvider.label(for: $0) },
                    mode: self.calendarManager.statusBarMode,
                    now: now
                )

                self.updatePulsingState(urgency: content.urgency)
                self.adjustTimerForUrgency(content.urgency)
            } else {
                content = StatusBarContent(
                    title: event != nil && onlyMeetings
                        ? NSLocalizedString("No upcoming meetings", comment: "Status bar title when only meetings are counted down and none is coming")
                        : NSLocalizedString("No upcoming events", comment: "Status bar title when no events"),
                    tooltip: nil,
                    urgency: .normal
                )
                self.stopPulsing()
                // Keep the next event's refresh rate so the start alert stays on time.
                let nextUrgency = event.map { MeetingUrgency.from(minutesUntil: Int($0.startDate.timeIntervalSince(Date())) / 60) } ?? .normal
                self.adjustTimerForUrgency(nextUrgency)
            }

            self.applyStatusBarContent(button: button, content: content)
            self.hudController.tick(now: now)
            let force = self.forceNotificationRescheduleOnRefresh && self.calendarManager.notificationsEnabled
            self.forceNotificationRescheduleOnRefresh = false
            self.maybeRescheduleNotifications(force: force, reason: force ? .systemTime : .forced)
        }
    }

    /// A meeting for the in-progress state: a join link, or attendees unless
    /// the countdown follows meetings with a link only.
    private static func isMeeting(_ event: EKEvent, requireJoinLink: Bool) -> Bool {
        let hasJoinLink = MeetingURLDetector.extract(from: event) != nil
        if requireJoinLink { return hasJoinLink }
        return hasJoinLink || !(event.attendees ?? []).isEmpty
    }

    private func applyStatusBarContent(button: NSStatusBarButton, content: StatusBarContent) {
        // Always render fresh countdown text or pill. The item may resize; an
        // open popover keeps the anchor it opened with.
        let filled = content.phase.isFilled && calendarManager.urgencyColorsEnabled
        let metrics = statusItemMetrics(
            button: button,
            requiredTitleWidth: StatusItemRenderer.requiredWidth(
                title: content.title,
                phase: content.phase,
                filled: filled,
                glyphWidth: statusGlyph?.size.width ?? 0
            )
        )
        let presentation = spacePolicy.update(
            availableWidth: metrics.availableWidth,
            requiredWidth: metrics.requiredWidth,
            notchMargin: metrics.notchMargin
        )
        let showsText = presentation == .text

        if filled, let pill = StatusItemRenderer.pillImage(
            glyph: statusGlyph,
            title: showsText ? content.title : nil,
            phase: content.phase,
            barThickness: NSStatusBar.system.thickness
        ) {
            // Soon and now: one filled pill, glyph and text drawn together.
            button.title = ""
            button.attributedTitle = NSAttributedString(string: "")
            button.image = pill
            button.imagePosition = .imageOnly
        } else {
            button.image = statusGlyph
            if showsText {
                button.attributedTitle = StatusItemRenderer.plainTitle(content.title, phase: content.phase)
                button.imagePosition = .imageLeading
            } else {
                button.title = ""
                button.attributedTitle = NSAttributedString(string: "")
                button.imagePosition = .imageOnly
            }
        }

        button.toolTip = showsText ? content.tooltip : (content.tooltip ?? content.title)
        button.setAccessibilityLabel(content.tooltip ?? content.title)
        popoverAnchorController.refreshIfNeeded()
    }

    private func statusItemMetrics(button: NSStatusBarButton, requiredTitleWidth: CGFloat) -> (availableWidth: CGFloat, requiredWidth: CGFloat, notchMargin: CGFloat) {
        let window = button.window
        let screen = window?.screen ?? NSScreen.main
        let screenFrame = screen?.frame ?? .zero

        // Update window-state tracking so we can distinguish "hidden by macOS"
        // from "not laid out yet at launch".
        if let window = window {
            statusItemWindowState = .visible(minX: window.frame.minX)
        } else if statusItemWindowState != .notYetLaidOut {
            statusItemWindowState = .hidden
        }

        // On notched displays, `auxiliaryTopRightArea.minX` is the right edge of the
        // notch and therefore the left boundary of the menu-bar extras area. macOS
        // hides extras whose left edge crosses that frontier. On non-notched
        // displays the frontier is bounded by the front app's menus, which no public
        // API exposes, so we rely on hidden-item detection plus a sticky latch.
        let isNotched = (screen?.safeAreaInsets.top ?? 0) > 0
        let frontierMinX = isNotched ? screen?.auxiliaryTopRightArea?.minX : nil

        if statusItemWindowState == .hidden && frontierMinX == nil {
            collapsedWhileHidden = true
        }

        let windowState: StatusBarItemWindowState
        if collapsedWhileHidden && frontierMinX == nil {
            // Stay icon-only on non-notched displays after macOS has hidden us.
            windowState = .hidden
        } else {
            windowState = statusItemWindowState
        }

        let availableWidth = StatusBarSpaceMetrics.availableWidth(
            windowState: windowState,
            frontierMinX: frontierMinX,
            generousWidth: screenFrame.width
        )

        let requiredWidth = requiredTitleWidth

        let notchMargin: CGFloat = frontierMinX != nil ? 60 : 0

        return (availableWidth, requiredWidth, notchMargin)
    }

    private func updatePulsingState(urgency: MeetingUrgency) {
        if StatusItemPulsePolicy.shouldPulse(
            urgency: urgency,
            urgencyColorsEnabled: calendarManager.urgencyColorsEnabled,
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        ) {
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

    private func rescheduleNotifications(reason: DiagnosticRescheduleReason = .forced) {
        guard calendarManager.notificationsEnabled else {
            // Clear all pending notifications if disabled
            Diagnostics.record(.notificationsCleared, throttleKey: "notifications.cleared", minInterval: 300)
            notificationRetryWorkItem?.cancel()
            notificationRetryWorkItem = nil
            calendarManager.notificationStatusMessage = nil
            notificationManager.clearAllPendingNotifications()
            return
        }

        notificationRetryWorkItem?.cancel()
        notificationRetryWorkItem = nil

        let eventsToSchedule = alertableUpcomingEvents()
        Diagnostics.record(.notificationsRescheduled(reason: reason, eventCount: eventsToSchedule.count))

        notificationManager.scheduleNotifications(
            for: eventsToSchedule,
            timing: calendarManager.notificationTiming
        ) { [weak self] result in
            self?.handleNotificationSchedulingResult(result)
        }
    }

    private func handleNotificationSchedulingResult(_ result: NotificationSchedulingResult) {
        calendarManager.notificationStatusMessage = NotificationSchedulingFeedback.message(for: result)
        Diagnostics.record(.notificationsScheduled(result: String(describing: result)))
        guard NotificationSchedulingFeedback.shouldRetry(result), calendarManager.notificationsEnabled else {
            notificationRetryWorkItem?.cancel()
            notificationRetryWorkItem = nil
            return
        }

        let retry = DispatchWorkItem { [weak self] in
            self?.maybeRescheduleNotifications(force: true)
        }
        notificationRetryWorkItem?.cancel()
        notificationRetryWorkItem = retry
        DispatchQueue.main.asyncAfter(deadline: .now() + 60, execute: retry)
    }

    /// Upcoming events that may notify: badge-only calendars and muted or
    /// hidden events (PEEK-273) are left out.
    private func alertableUpcomingEvents() -> [EKEvent] {
        let events = calendarManager.allUpcomingEvents.isEmpty
            ? calendarManager.upcomingEvents
            : calendarManager.allUpcomingEvents
        return events.filter { calendarManager.alerts(for: $0) }
    }

    private func currentNotificationEventSignature() -> [String] {
        NotificationContentSignature.schedule(
            eventSignatures: alertableUpcomingEvents().compactMap(NotificationContentSignature.make(for:)),
            timeZone: TimeZone.current
        )
    }

    private func maybeRescheduleNotifications(force: Bool, reason: DiagnosticRescheduleReason = .forced) {
        if !force && !calendarManager.notificationsEnabled {
            return
        }
        let signature = currentNotificationEventSignature()
        if force || signature != lastScheduledEventSignature {
            lastScheduledEventSignature = signature
            rescheduleNotifications(reason: force ? reason : .eventsChanged)
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

extension AppDelegate: NSWindowDelegate, NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        popoverAnchorController.detach()
        updateMenuBar()
    }

    func windowWillClose(_ notification: Notification) {
        // If the user closes onboarding via the traffic light, treat it as finished.
        guard (notification.object as? NSWindow) === onboardingWindow else { return }
        calendarManager.completeOnboarding()
        onboardingWindow = nil
        let granted = calendarManager.refreshAuthorizationStatus()
        handleCalendarAccessChange(granted: granted, shouldRefresh: true)
    }
}
