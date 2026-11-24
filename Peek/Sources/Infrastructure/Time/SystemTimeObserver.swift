import AppKit
import Foundation

/// A system event after which every alert time must be recomputed (PEEK-271).
enum SystemTimeChange: String, CaseIterable {
    case wake
    case timeZone
    case clock
    case dayChanged
}

protocol SystemTimeObserving: AnyObject {
    /// Calls `handler` on the main queue, at most once per debounce interval,
    /// with every change seen in that interval.
    func start(_ handler: @escaping (Set<SystemTimeChange>) -> Void)
    func stop()
}

/// Joins the wake, time zone, clock and day-change signals behind one seam,
/// with a one-second debounce: a wake often arrives with a clock change.
final class SystemTimeObserver: SystemTimeObserving {
    static let debounce: TimeInterval = 1

    private var observers: [(center: NotificationCenter, token: NSObjectProtocol)] = []
    private var pending = Set<SystemTimeChange>()
    private var workItem: DispatchWorkItem?
    private var handler: ((Set<SystemTimeChange>) -> Void)?

    func start(_ handler: @escaping (Set<SystemTimeChange>) -> Void) {
        stop()
        self.handler = handler
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.didWakeNotification, .wake)
        observe(.default, .NSSystemTimeZoneDidChange, .timeZone)
        observe(.default, .NSSystemClockDidChange, .clock)
        observe(.default, .NSCalendarDayChanged, .dayChanged)
    }

    func stop() {
        for observer in observers {
            observer.center.removeObserver(observer.token)
        }
        observers.removeAll()
        workItem?.cancel()
        workItem = nil
        pending.removeAll()
        handler = nil
    }

    deinit {
        stop()
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ change: SystemTimeChange) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            self?.record(change)
        }
        observers.append((center, token))
    }

    private func record(_ change: SystemTimeChange) {
        if change == .timeZone {
            // Foundation caches the system zone; drop the cache so
            // `TimeZone.current` and new formatters see the new zone.
            NSTimeZone.resetSystemTimeZone()
        }
        pending.insert(change)
        workItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let changes = self.pending
            self.pending.removeAll()
            self.workItem = nil
            self.handler?(changes)
        }
        workItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.debounce, execute: work)
    }
}
