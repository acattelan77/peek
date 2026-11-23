import Foundation

/// Maps a meeting URL's host to a human-readable conference provider label, and
/// to the URL that opens the provider's own Mac app when it has one.
enum MeetingProvider {
    static func label(for url: URL) -> String {
        guard let host = url.host?.lowercased() else {
            return NSLocalizedString("Meeting", comment: "Generic meeting provider")
        }
        if host.contains("zoom") { return "Zoom" }
        if host.contains("meet.google") { return "Google Meet" }
        if host.contains("teams.microsoft") || host.contains("teams.live") { return "Teams" }
        if host.contains("webex") { return "Webex" }
        if host.contains("gotomeeting") || host.contains("goto.com") { return "GoTo" }
        if host == "app.slack.com" { return "Slack" }
        if host == "chime.aws" { return "Chime" }
        if host == "meet.jit.si" { return "Jitsi" }
        if host == "facetime.apple.com" { return "FaceTime" }
        if host.contains("ringcentral") { return "RingCentral" }
        if host.contains("whereby") { return "Whereby" }
        if host.contains("discord") { return "Discord" }
        return NSLocalizedString("Meeting", comment: "Generic meeting provider")
    }

    /// The deep link that opens this meeting in the provider's Mac app, or `nil`
    /// when the provider has no app scheme Peek knows. The caller must check that
    /// an app handles the scheme before opening it, and fall back to `url`.
    static func nativeAppURL(for url: URL) -> URL? {
        guard MeetingURLDetector.isURLSafe(url),
              let host = url.host?.lowercased(),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }

        if host.hasSuffix("zoom.us") || host.hasSuffix("zoomgov.com") {
            return zoomAppURL(host: host, components: components)
        }

        if host == "teams.microsoft.com" || host == "teams.live.com" {
            // Teams registers msteams: and accepts the web path unchanged.
            var native = components
            native.scheme = "msteams"
            native.host = nil
            return native.url
        }

        return nil
    }

    private static func zoomAppURL(host: String, components: URLComponents) -> URL? {
        let parts = components.path.split(separator: "/").map(String.init)
        guard parts.count >= 2, parts[0] == "j" || parts[0] == "s" || parts[0] == "w" else { return nil }
        let meetingID = parts[1]
        guard !meetingID.isEmpty, meetingID.allSatisfy(\.isNumber) else { return nil }

        var native = URLComponents()
        native.scheme = "zoommtg"
        native.host = host
        native.path = "/join"
        var items = [URLQueryItem(name: "action", value: "join"), URLQueryItem(name: "confno", value: meetingID)]
        if let password = components.queryItems?.first(where: { $0.name == "pwd" })?.value {
            items.append(URLQueryItem(name: "pwd", value: password))
        }
        native.queryItems = items
        return native.url
    }
}
