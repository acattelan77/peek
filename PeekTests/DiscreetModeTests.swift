import XCTest
import EventKit
@testable import Peek

/// PEEK-274: discreet mode while sharing the screen.
final class DiscreetModeTests: XCTestCase {
    private final class FakeSignals: ScreenShareSignalReading {
        var mirrored = false
        func isDisplayMirrored() -> Bool { mirrored }
    }

    private final class FakeRegistrar: HotkeyRegistering {
        var registered: (keyCode: UInt32, modifiers: UInt32)?
        var unregisterCount = 0
        func register(keyCode: UInt32, modifiers: UInt32) -> OSStatus {
            registered = (keyCode, modifiers)
            return noErr
        }
        func unregister() { unregisterCount += 1 }
    }

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "PeekTests.DiscreetMode.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        TestDefaults.remove(suiteName)
        super.tearDown()
    }

    // MARK: Policy

    func testManualWinsOverEverything() {
        XCTAssertEqual(
            DiscreetModePolicy.reason(manual: true, detectsMirroring: false, displayMirrored: false, mirroringDismissed: false),
            .manual
        )
        XCTAssertEqual(
            DiscreetModePolicy.reason(manual: true, detectsMirroring: true, displayMirrored: true, mirroringDismissed: true),
            .manual
        )
    }

    func testMirroringTurnsOnOnlyWhenDetectionIsOnAndNotDismissed() {
        XCTAssertEqual(
            DiscreetModePolicy.reason(manual: false, detectsMirroring: true, displayMirrored: true, mirroringDismissed: false),
            .mirroring
        )
        XCTAssertNil(DiscreetModePolicy.reason(manual: false, detectsMirroring: false, displayMirrored: true, mirroringDismissed: false))
        XCTAssertNil(DiscreetModePolicy.reason(manual: false, detectsMirroring: true, displayMirrored: true, mirroringDismissed: true))
        XCTAssertNil(DiscreetModePolicy.reason(manual: false, detectsMirroring: true, displayMirrored: false, mirroringDismissed: false))
    }

    func testFullScreenAlertDegradesToTheCard() {
        XCTAssertEqual(DiscreetModePolicy.startAlert(.fullScreen, discreet: true), .hud)
        XCTAssertEqual(DiscreetModePolicy.startAlert(.hud, discreet: true), .hud)
        XCTAssertEqual(DiscreetModePolicy.startAlert(.none, discreet: true), .none)
        XCTAssertEqual(DiscreetModePolicy.startAlert(.fullScreen, discreet: false), .fullScreen)
    }

    func testMenuBarNeverNamesAContactWhileDiscreet() {
        XCTAssertEqual(DiscreetModePolicy.labelStyle(.person, discreet: true), .eventTitle)
        XCTAssertEqual(DiscreetModePolicy.labelStyle(.person, discreet: false), .person)
    }

    func testDiscreetMetaKeepsOnlyProviderAndDuration() {
        XCTAssertEqual(DiscreetModePolicy.meta(providerLabel: "Zoom", duration: "30 min"), "Zoom · 30 min")
        XCTAssertEqual(DiscreetModePolicy.meta(providerLabel: nil, duration: "1 hr"), "1 hr")
        XCTAssertEqual(DiscreetModePolicy.meta(providerLabel: nil, duration: nil), "")
    }

    func testEventRowMetaHidesLocationAndNotes() {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = "Renewal"
        event.startDate = Date(timeIntervalSinceNow: 3600)
        event.endDate = Date(timeIntervalSinceNow: 5400)
        event.location = "Marco's office, Via Nazionale 1"
        event.notes = "Confidential: renewal position"
        let meta = EventPresentation.discreetMeta(event)
        XCTAssertFalse(meta.contains("Marco"))
        XCTAssertFalse(meta.contains("Confidential"))
        XCTAssertFalse(meta.isEmpty, "The duration is still shown")
    }

    // MARK: Controller

    func testDefaultsAreOffWithMirroringDetectionAndAShortcut() {
        let controller = DiscreetModeController(defaults: defaults, signals: FakeSignals())
        XCTAssertFalse(controller.isActive)
        XCTAssertTrue(controller.detectsMirroring)
        XCTAssertEqual(controller.hotkey, .ctrlOptionD)
    }

    func testToggleTurnsOnAndOffAndPersists() {
        let controller = DiscreetModeController(defaults: defaults, signals: FakeSignals())
        controller.toggle()
        XCTAssertEqual(controller.reason, .manual)
        XCTAssertTrue(DiscreetModeController(defaults: defaults, signals: FakeSignals()).isActive, "Survives a restart")
        controller.toggle()
        XCTAssertFalse(controller.isActive)
    }

    func testMirroringTurnsOnAndToggleDismissesUntilMirroringEnds() {
        let signals = FakeSignals()
        let controller = DiscreetModeController(defaults: defaults, signals: signals)
        signals.mirrored = true
        controller.refreshSignals()
        XCTAssertEqual(controller.reason, .mirroring)

        controller.toggle()
        XCTAssertFalse(controller.isActive, "The user can still turn it off while mirroring")
        controller.refreshSignals()
        XCTAssertFalse(controller.isActive, "Stays off for this mirroring session")

        signals.mirrored = false
        controller.refreshSignals()
        signals.mirrored = true
        controller.refreshSignals()
        XCTAssertEqual(controller.reason, .mirroring, "The next mirroring session is covered again")
    }

    func testMirroringIsIgnoredWhenDetectionIsOff() {
        let signals = FakeSignals()
        signals.mirrored = true
        let controller = DiscreetModeController(defaults: defaults, signals: signals)
        controller.detectsMirroring = false
        XCTAssertFalse(controller.isActive)
    }

    // MARK: Shortcut

    func testShortcutRegistersAndOffUnregisters() {
        let registrar = FakeRegistrar()
        XCTAssertEqual(GlobalHotkeyCoordinator.apply(DiscreetHotkeyOption.ctrlOptionD, using: registrar), .active)
        XCTAssertEqual(registrar.registered?.keyCode, 2)
        XCTAssertEqual(GlobalHotkeyCoordinator.apply(DiscreetHotkeyOption.off, using: registrar), .active)
        XCTAssertEqual(registrar.unregisterCount, 1)
    }

    func testShortcutOptionsAreDistinct() {
        let combos = DiscreetHotkeyOption.allCases.filter { $0 != .off }.map { "\($0.keyCode)-\($0.modifiers)" }
        XCTAssertEqual(Set(combos).count, combos.count)
    }
}
