import Foundation

/// Maps a meeting URL's host to a human-readable conference provider label.
enum MeetingProvider {
    static func label(for url: URL) -> String {
        guard let host = url.host?.lowercased() else {
            return NSLocalizedString("Meeting", comment: "Generic meeting provider")
        }
        if host.contains("zoom") { return "Zoom" }
        if host.contains("meet.google") { return "Google Meet" }
        if host.contains("teams.microsoft") { return "Teams" }
        if host.contains("webex") { return "Webex" }
        if host.contains("gotomeeting") { return "GoToMeeting" }
        if host.contains("whereby") { return "Whereby" }
        if host.contains("discord") { return "Discord" }
        return NSLocalizedString("Meeting", comment: "Generic meeting provider")
    }
}
