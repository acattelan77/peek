import Foundation
@testable import Peek

/// A test double for `LaunchAtLoginControlling` that lets tests control the
/// current launch-at-login value and simulate registration errors.
final class FakeLaunchAtLoginController: LaunchAtLoginControlling {
    var currentValue: Bool
    var errorToThrow: Error?
    var mutatesCurrentValue = true

    init(currentValue: Bool = false) {
        self.currentValue = currentValue
    }

    func setEnabled(_ enabled: Bool) throws {
        if let error = errorToThrow {
            throw error
        }
        if mutatesCurrentValue {
            currentValue = enabled
        }
    }
}
