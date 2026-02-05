import Foundation
import EventKit

struct MeetingURLDetector {
    static let patterns: [String] = [
        "https://[a-zA-Z0-9.-]+\\.zoom\\.us/j/[0-9]+",
        "https://meet\\.google\\.com/[a-z-]+",
        "https://teams\\.microsoft\\.com/l/meetup-join/[^\\s]+",
        "https://[a-zA-Z0-9.-]+\\.webex\\.com/[^\\s]+",
        "https://[a-zA-Z0-9.-]+\\.gotomeeting\\.com/[^\\s]+",
        "https://whereby\\.com/[a-z0-9-]+",
        "https://discord\\.gg/[a-zA-Z0-9]+",
        "https://discord\\.com/[^\\s]+"
    ]

    static let trustedDomains: [String] = [
        "zoom.us",
        "meet.google.com",
        "teams.microsoft.com",
        "webex.com",
        "gotomeeting.com",
        "whereby.com",
        "discord.gg",
        "discord.com"
    ]

    private static let maxNotesLength = 2000
    private static let maxLocationLength = 500

    static func extract(from event: EKEvent) -> URL? {
        extractFrom(notes: event.notes, location: event.location, url: event.url)
    }

    static func extractFrom(notes: String?, location: String?, url: URL?) -> URL? {
        if let notes = notes?.prefix(maxNotesLength) {
            if let url = findURL(in: String(notes)) {
                return url
            }
        }

        if let location = location?.prefix(maxLocationLength) {
            if let url = findURL(in: String(location)) {
                return url
            }
        }

        if let url = url, isURLSafe(url) {
            return url
        }

        return nil
    }

    static func findURL(in text: String, patterns: [String] = MeetingURLDetector.patterns) -> URL? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                continue
            }

            if let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                let urlString = String(text[range])
                if let url = URL(string: urlString), isURLSafe(url) {
                    return url
                }
            }
        }
        return nil
    }

    static func isURLSafe(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" else {
            return false
        }

        guard let host = url.host?.lowercased() else {
            return false
        }

        for domain in trustedDomains {
            if host == domain || host.hasSuffix(".\(domain)") {
                return true
            }
        }

        return false
    }
}
