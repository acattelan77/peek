import AppKit
import Foundation
import UserNotifications

/// Writes the diagnostics file into Peek's own Application Support folder and
/// shows it in the Finder, so the user decides whether to share it. Peek's
/// sandbox can read user-chosen files but not write them, so the file stays
/// in Peek's container rather than going through a save panel.
enum DiagnosticsExporter {
    enum ExportError: Error {
        case noDirectory
    }

    static func exportsDirectory() -> URL? {
        DiagnosticsLog.directoryURL()?.appendingPathComponent("Exports", isDirectory: true)
    }

    /// Builds the report on the main thread (it reads `CalendarManager`),
    /// writes it, reveals it, and calls back with the file or an error.
    static func exportAndReveal(
        calendarManager: CalendarManager,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            UNUserNotificationCenter.current().getPendingNotificationRequests { pending in
                DispatchQueue.main.async {
                    let result = Result<URL, Error> {
                        let report = makeReport(
                            calendarManager: calendarManager,
                            notificationAuthorization: describe(settings.authorizationStatus),
                            pendingNotificationCount: pending.count
                        )
                        let url = try write(report)
                        Diagnostics.record(.diagnosticsExported(entryCount: report.journal.count, payloadCount: report.payloads.count))
                        return url
                    }
                    if case .success(let url) = result {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                    completion(result)
                }
            }
        }
    }

    static func makeReport(
        calendarManager: CalendarManager,
        notificationAuthorization: String,
        pendingNotificationCount: Int?,
        now: Date = Date(),
        log: DiagnosticsLog = .shared,
        payloadStore: MetricPayloadStore = MetricKitCollector.shared.store
    ) -> DiagnosticsReport {
        let version = AppVersion.from()
        payloadStore.pruneExpired(now: now)
        return DiagnosticsReport(
            generatedAt: now,
            appVersion: version.marketingVersion,
            appBuild: version.buildNumber,
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "",
            systemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            localeIdentifier: Locale.current.identifier,
            timeZoneIdentifier: TimeZone.current.identifier,
            calendarAccess: calendarManager.hasCalendarAccess,
            notificationAuthorization: notificationAuthorization,
            pendingNotificationCount: pendingNotificationCount,
            settings: .from(calendarManager),
            journal: log.journal(now: now),
            payloads: payloadStore.all().map {
                DiagnosticsReport.Payload(fileName: $0.fileName, created: $0.created, data: $0.data)
            }
        )
    }

    static func write(_ report: DiagnosticsReport, to directory: URL? = exportsDirectory()) throws -> URL {
        guard let directory else { throw ExportError.noDirectory }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(DiagnosticsReport.fileName(for: report.generatedAt))
        try report.jsonData().write(to: url, options: .atomic)
        return url
    }

    static func describe(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .authorized: return "authorized"
        case .provisional: return "provisional"
        @unknown default: return "unknown"
        }
    }
}
