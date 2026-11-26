import Foundation

/// Runs one asynchronous job at a time. A job submitted while another runs
/// waits; a newer submission replaces a waiting one, so a burst of requests
/// becomes the running job plus one follow-up with the latest input.
///
/// PEEK-286: notification reschedules used to overlap at launch. One pass
/// removed the reminders another pass had just added, and that pass then
/// reported "Some reminders could not be scheduled".
///
/// Not thread-safe: submit and finish on the main thread.
final class CoalescingSerialQueue {
    /// A job calls `done` exactly once when it has finished.
    typealias Job = (_ done: @escaping () -> Void) -> Void

    private var isRunning = false
    private var waiting: Job?

    /// True while a newer job waits to run after the current one; the current
    /// job's result is then out of date.
    var hasWaitingJob: Bool { waiting != nil }

    var isIdle: Bool { !isRunning && waiting == nil }

    func submit(_ job: @escaping Job) {
        if isRunning {
            waiting = job
        } else {
            run(job)
        }
    }

    private func run(_ job: @escaping Job) {
        isRunning = true
        var finished = false
        job { [weak self] in
            guard let self, !finished else { return }
            finished = true
            self.isRunning = false
            if let next = self.waiting {
                self.waiting = nil
                self.run(next)
            }
        }
    }
}
