import Foundation

/// Throwaway `UserDefaults` suites for tests.
///
/// `UserDefaults().removeSuite(named:)` only drops a suite from the standard
/// search list; it leaves the suite's plist in Library/Preferences, so every
/// test run used to leave files behind. `remove(_:)` empties the domain and
/// deletes its plist.
enum TestDefaults {
    static let prefix = "com.peek.app.tests."

    /// A new, empty suite whose name is unique to this call.
    static func make(_ label: String = "suite") -> (defaults: UserDefaults, name: String) {
        let name = "\(prefix)\(label).\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: name) else {
            preconditionFailure("Could not create a UserDefaults suite for tests")
        }
        return (defaults, name)
    }

    /// Empties the suite and deletes its plist, if any.
    static func remove(_ name: String) {
        UserDefaults().removePersistentDomain(forName: name)
        CFPreferencesAppSynchronize(name as CFString)
        if let url = plistURL(for: name) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Where `cfprefsd` keeps the suite on disk for this process.
    static func plistURL(for name: String) -> URL? {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Preferences", isDirectory: true)
            .appendingPathComponent("\(name).plist")
    }
}
