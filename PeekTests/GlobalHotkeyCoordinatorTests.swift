import XCTest
@testable import Peek

/// Deterministic test double for the Carbon hotkey seam.
private final class FakeHotkeyRegistrar: HotkeyRegistering {
    private(set) var registerCallCount = 0
    private(set) var registeredKeyCode: UInt32?
    private(set) var registeredModifiers: UInt32?
    var statusToReturn: OSStatus = noErr

    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32) -> OSStatus {
        registerCallCount += 1
        registeredKeyCode = keyCode
        registeredModifiers = modifiers
        return statusToReturn
    }

    func unregister() {}
}

final class GlobalHotkeyCoordinatorTests: XCTestCase {
    func testApplyRegistersSelectedHotkeyCombination() {
        let registrar = FakeHotkeyRegistrar()

        let result = GlobalHotkeyCoordinator.apply(.cmdShiftP, using: registrar)

        XCTAssertEqual(registrar.registerCallCount, 1)
        XCTAssertEqual(registrar.registeredKeyCode, HotkeyOption.cmdShiftP.keyCode)
        XCTAssertEqual(registrar.registeredModifiers, HotkeyOption.cmdShiftP.modifiers)
        XCTAssertTrue(result.isActive)
        XCTAssertNil(result.errorMessage)
        XCTAssertEqual(result, .active)
    }

    func testApplyReturnsActiveWhenRegistrationSucceeds() {
        let registrar = FakeHotkeyRegistrar()
        registrar.statusToReturn = noErr

        let result = GlobalHotkeyCoordinator.apply(.cmdShiftC, using: registrar)

        XCTAssertTrue(result.isActive)
        XCTAssertNil(result.errorMessage)
    }

    func testApplySurfacesFailureWhenRegistrationFails() {
        let registrar = FakeHotkeyRegistrar()
        registrar.statusToReturn = -9878 // eventHotKeyExistsErr

        let result = GlobalHotkeyCoordinator.apply(.cmdOptionC, using: registrar)

        XCTAssertFalse(result.isActive)
        let message = try? XCTUnwrap(result.errorMessage)
        XCTAssertNotNil(message)
        // The message names the offending shortcut so the user knows which one failed.
        XCTAssertTrue(result.errorMessage?.contains(HotkeyOption.cmdOptionC.rawValue) ?? false)
    }

    func testDistinctHotkeyOptionsMapToDistinctModifiers() {
        let shiftRegistrar = FakeHotkeyRegistrar()
        let optionRegistrar = FakeHotkeyRegistrar()

        _ = GlobalHotkeyCoordinator.apply(.cmdShiftC, using: shiftRegistrar)
        _ = GlobalHotkeyCoordinator.apply(.cmdOptionC, using: optionRegistrar)

        // Same key, different modifiers.
        XCTAssertEqual(shiftRegistrar.registeredKeyCode, optionRegistrar.registeredKeyCode)
        XCTAssertNotEqual(shiftRegistrar.registeredModifiers, optionRegistrar.registeredModifiers)
    }
}
