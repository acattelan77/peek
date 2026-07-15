import Foundation

struct AppVersion: Equatable {
    let marketingVersion: String
    let buildNumber: String

    var displayText: String {
        String(
            format: NSLocalizedString("Version %@ (%@)", comment: "App version and build number"),
            marketingVersion,
            buildNumber
        )
    }

    static func from(bundle: Bundle = .main) -> AppVersion {
        AppVersion(
            marketingVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—",
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        )
    }
}
