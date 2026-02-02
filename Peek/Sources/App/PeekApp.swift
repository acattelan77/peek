import SwiftUI
import AppKit
import Combine
import Carbon
import EventKit

// MARK: - Meeting Urgency Levels
enum MeetingUrgency {
    case critical   // < 2 minutes (pulsing, red)
    case urgent     // 2-10 minutes (orange)
    case normal     // > 10 minutes (default color)

    static func from(minutesUntil: Int) -> MeetingUrgency {
        switch minutesUntil {
        case ..<2:
            return .critical
        case 2..<10:
            return .urgent
        default:
            return .normal
        }
    }
}

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
    private static let kUpdateInterval: TimeInterval = 60 // seconds
    private static let kUrgentUpdateInterval: TimeInterval = 5 // Update every 5 seconds when meeting is close

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var calendarManager: CalendarManager!
    private var cancellables = Set<AnyCancellable>()
    private var hotKeyRef: EventHotKeyRef?
    private var updateTimer: Timer?
    private let notificationManager = NotificationManager.shared
    private var pulseTimer: Timer?
    private var isPulsing = false

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

            button.title = "Loading..."
            button.action = #selector(togglePopover)
            button.target = self

            // Enable Cmd+drag to reposition
            button.sendAction(on: [.leftMouseUp, .leftMouseDown, .leftMouseDragged])
        }

        // Create popover
        popover = NSPopover()
        popover.behavior = .transient

        let menuBarView = MenuBarView(calendarManager: calendarManager, closePopover: { [weak self] in
            self?.popover.performClose(nil)
        })

        popover.contentViewController = NSHostingController(rootView: menuBarView)

        // Observe changes to enabled calendars and refresh when changed
        calendarManager.$enabledCalendarIDs
            .sink { [weak self] _ in
                self?.updateMenuBar()
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
            .sink { [weak self] _ in
                self?.rescheduleNotifications()
            }
            .store(in: &cancellables)

        calendarManager.$notificationTiming
            .sink { [weak self] _ in
                self?.rescheduleNotifications()
            }
            .store(in: &cancellables)

        // Register global hotkey (Cmd+Shift+C)
        registerGlobalHotkey()

        // Request calendar access and start monitoring
        calendarManager.requestAccess { [weak self] granted, error in
            if granted {
                self?.updateMenuBar()
                self?.startTimer()

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
                    if let button = self?.statusItem.button {
                        button.title = "No Calendar Access"
                        button.toolTip = "Grant permission in System Settings → Privacy & Security → Calendars"
                    }
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

        // Check if the event is a mouse event and if Cmd key is pressed
        if let event = NSApp.currentEvent,
           event.type == .leftMouseDown || event.type == .leftMouseDragged,
           event.modifierFlags.contains(.command) {
            // Allow the system to handle Cmd+drag for repositioning
            return
        }

        // Only toggle on click (leftMouseUp), not on drag events
        if let event = NSApp.currentEvent, event.type == .leftMouseDragged {
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Toggle urgency colors only when SHOWING the popover
            calendarManager.urgencyColorsEnabled.toggle()
            calendarManager.savePreferences()

            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func updateMenuBar() {
        calendarManager.fetchNextEvent { [weak self] event in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let button = self.statusItem.button {
                    let eventCount = self.calendarManager.upcomingEvents.count

                    if let event = event, eventCount > 0 {
                        let (title, tooltip, urgency) = self.formatStatusBarText(event: event, eventCount: eventCount)

                        // Set title and tooltip first
                        button.title = title
                        button.toolTip = tooltip

                        // Apply color based on urgency (AFTER setting title)
                        self.applyUrgencyStyle(to: button, urgency: urgency)

                        // Handle pulsing animation for imminent meetings
                        self.updatePulsingState(urgency: urgency)

                        // Adjust timer frequency based on urgency
                        self.adjustTimerForUrgency(urgency)
                    } else {
                        button.title = self.calendarManager.statusBarMode == .iconOnly ? "" : "No upcoming events"
                        button.toolTip = nil
                        button.attributedTitle = NSAttributedString(string: button.title)
                        self.stopPulsing()
                    }
                }

                // Schedule notifications for upcoming events
                self.rescheduleNotifications()
            }
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
        let newInterval: TimeInterval

        switch urgency {
        case .critical, .urgent:
            newInterval = Self.kUrgentUpdateInterval
        case .normal:
            newInterval = Self.kUpdateInterval
        }

        // Only restart timer if interval changed
        if updateTimer?.timeInterval != newInterval {
            startTimer(interval: newInterval)
        }
    }

    private func rescheduleNotifications() {
        guard calendarManager.notificationsEnabled else {
            // Clear all notifications if disabled
            notificationManager.scheduleNotifications(for: [], timing: .none)
            return
        }

        notificationManager.scheduleNotifications(
            for: calendarManager.upcomingEvents,
            timing: calendarManager.notificationTiming
        )
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
            return ("", event.title, urgency)
        }

        let eventTitle = event.title ?? "Untitled Event"
        let maxTitleLength = 20
        let truncatedTitle = eventTitle.count > maxTitleLength
            ? String(eventTitle.prefix(maxTitleLength)) + "..."
            : eventTitle

        let countSuffix = (eventCount > 1 && showCount) ? " (+\(eventCount - 1))" : ""

        var timeString: String

        if mode == .timeUntil {
            // Time until mode
            if event.startDate > now {
                let interval = event.startDate.timeIntervalSince(now)
                let hours = Int(interval) / 3600
                let minutes = (Int(interval) % 3600) / 60

                if hours > 24 {
                    let days = hours / 24
                    timeString = "\(days)d"
                } else if hours > 0 {
                    timeString = "\(hours)h \(minutes)m"
                } else if minutes > 0 {
                    timeString = "\(minutes)m"
                } else {
                    timeString = "NOW!"
                }
            } else {
                timeString = "NOW!"
            }
        } else {
            // Actual time mode
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            timeString = formatter.string(from: event.startDate)
        }

        let title = "\(timeString) - \(truncatedTitle)\(countSuffix)"
        let tooltip = eventTitle.count > maxTitleLength ? "\(timeString) - \(eventTitle)" : nil

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
