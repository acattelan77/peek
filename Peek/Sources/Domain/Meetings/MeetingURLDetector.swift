import Foundation
import EventKit

struct MeetingURLDetector {
    /// Join-link patterns, most specific first. Every match must also pass
    /// `isURLSafe`, so a pattern can be generous about paths and queries.
    static let patterns: [String] = [
        // Zoom and Zoom for Government: meetings, personal rooms, webinars, web client.
        "https://(?:[a-zA-Z0-9-]+\\.)*zoom(?:gov)?\\.(?:us|com)/(?:j|my|s|w|wc/join|wc)/[^\\s<>\"]+",
        // Google Meet, including lookup links and query strings.
        "https://meet\\.google\\.com/(?:lookup/)?[a-z0-9-]+(?:\\?[^\\s<>\"]*)?",
        // Microsoft Teams (work, school and personal).
        "https://teams\\.microsoft\\.com/(?:l/meetup-join|meet)/[^\\s<>\"]+",
        "https://teams\\.live\\.com/meet/[^\\s<>\"]+",
        // Webex.
        "https://[a-zA-Z0-9.-]+\\.webex\\.com/[^\\s<>\"]+",
        // GoTo Meeting (legacy and current domains).
        "https://(?:[a-zA-Z0-9-]+\\.)?gotomeeting\\.com/[^\\s<>\"]+",
        "https://meet\\.goto\\.com/[^\\s<>\"]+",
        // Slack huddles.
        "https://app\\.slack\\.com/huddle/[^\\s<>\"]+",
        // Amazon Chime.
        "https://chime\\.aws/[0-9]+",
        // Jitsi Meet.
        "https://meet\\.jit\\.si/[^\\s<>\"]+",
        // FaceTime links.
        "https://facetime\\.apple\\.com/join[^\\s<>\"]*",
        // RingCentral Video.
        "https://v\\.ringcentral\\.com/join/[^\\s<>\"]+",
        // Whereby.
        "https://whereby\\.com/[a-zA-Z0-9-]+",
        // Discord.
        "https://discord\\.gg/[a-zA-Z0-9]+",
        "https://discord\\.com/[^\\s<>\"]+"
    ]

    static let trustedDomains: [String] = [
        "zoom.us",
        "zoom.com",
        "zoomgov.com",
        "meet.google.com",
        "teams.microsoft.com",
        "teams.live.com",
        "webex.com",
        "gotomeeting.com",
        "meet.goto.com",
        "app.slack.com",
        "chime.aws",
        "meet.jit.si",
        "facetime.apple.com",
        "v.ringcentral.com",
        "whereby.com",
        "discord.gg",
        "discord.com"
    ]

    /// The domains that classified a link as `join` in the PEEK-111 calendar
    /// export JSON v1. Frozen: the export contract must not change silently when
    /// in-app detection learns new providers (see ADR 0003).
    static let exportV1JoinDomains: [String] = [
        "zoom.us",
        "meet.google.com",
        "teams.microsoft.com",
        "webex.com",
        "gotomeeting.com",
        "whereby.com",
        "discord.gg",
        "discord.com"
    ]

    private static let maxNotesLength = 4000
    private static let maxLocationLength = 500

    private static let compiledPatterns: [NSRegularExpression] = patterns.compactMap {
        try? NSRegularExpression(pattern: $0, options: [])
    }

    static func extract(from event: EKEvent) -> URL? {
        extractFrom(notes: event.notes, location: event.location, url: event.url)
    }

    /// Looks for a join link in the event's URL field first (calendar providers
    /// put the conference link there), then the location, then the notes.
    static func extractFrom(notes: String?, location: String?, url: URL?) -> URL? {
        if let url = url, isURLSafe(url) {
            return url
        }

        if let location = location?.prefix(maxLocationLength),
           let url = findURL(in: String(location)) {
            return url
        }

        if let notes = notes?.prefix(maxNotesLength),
           let url = findURL(in: String(notes)) {
            return url
        }

        return nil
    }

    /// Returns the earliest join link in `text`. Invitations often mention a
    /// dial-in or a second provider further down, so position wins over the
    /// order of `patterns`.
    static func findURL(in text: String) -> URL? {
        let range = NSRange(text.startIndex..., in: text)
        var best: (location: Int, url: URL)?

        for regex in compiledPatterns {
            for match in regex.matches(in: text, options: [], range: range) {
                if let current = best, match.range.location >= current.location { break }
                guard let matchRange = Range(match.range, in: text) else { continue }
                let urlString = sanitizedURLString(String(text[matchRange]))
                if let url = URL(string: urlString), isURLSafe(url) {
                    best = (match.range.location, url)
                    break
                }
            }
        }

        return best?.url
    }

    private static func sanitizedURLString(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?)]}>'\""))
    }

    static func isURLSafe(_ url: URL) -> Bool {
        isHTTPS(url, onAnyOf: trustedDomains)
    }

    /// The PEEK-111 export v1 join classification. Do not change; see
    /// `exportV1JoinDomains`.
    static func isExportV1JoinURL(_ url: URL) -> Bool {
        isHTTPS(url, onAnyOf: exportV1JoinDomains)
    }

    private static func isHTTPS(_ url: URL, onAnyOf domains: [String]) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" else {
            return false
        }

        guard let host = url.host?.lowercased() else {
            return false
        }

        return domains.contains { host == $0 || host.hasSuffix(".\($0)") }
    }
}
