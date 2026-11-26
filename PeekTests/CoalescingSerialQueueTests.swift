import XCTest
@testable import Peek

/// PEEK-286: notification reschedules run one at a time and coalesce.
final class CoalescingSerialQueueTests: XCTestCase {
    func testJobRunsAtOnceWhenIdle() {
        let queue = CoalescingSerialQueue()
        var ran = false
        queue.submit { done in ran = true; done() }
        XCTAssertTrue(ran)
        XCTAssertTrue(queue.isIdle)
    }

    func testJobsNeverOverlap() {
        let queue = CoalescingSerialQueue()
        var running = 0
        var maxRunning = 0
        var finishers: [() -> Void] = []
        for _ in 0..<3 {
            queue.submit { done in
                running += 1
                maxRunning = max(maxRunning, running)
                finishers.append { running -= 1; done() }
            }
        }
        while !finishers.isEmpty {
            finishers.removeFirst()()
        }
        XCTAssertEqual(maxRunning, 1)
        XCTAssertTrue(queue.isIdle)
    }

    func testBurstCoalescesIntoOneFollowUpWithTheLatestJob() {
        let queue = CoalescingSerialQueue()
        var log: [String] = []
        var finishFirst: (() -> Void)?
        queue.submit { done in log.append("first"); finishFirst = done }
        queue.submit { done in log.append("second"); done() }
        queue.submit { done in log.append("third"); done() }

        XCTAssertTrue(queue.hasWaitingJob)
        XCTAssertEqual(log, ["first"])

        finishFirst?()
        XCTAssertEqual(log, ["first", "third"])
        XCTAssertTrue(queue.isIdle)
    }

    func testCallingDoneTwiceDoesNotStartTwoJobs() {
        let queue = CoalescingSerialQueue()
        var finishFirst: (() -> Void)?
        var followUps = 0
        queue.submit { done in finishFirst = done }
        queue.submit { done in followUps += 1; _ = done }
        finishFirst?()
        finishFirst?()
        XCTAssertEqual(followUps, 1)
        XCTAssertFalse(queue.isIdle)
    }
}
