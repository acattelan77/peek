import Foundation

/// The meeting-context file another app (such as Northwind Notes) writes into a
/// folder the user chose, and Peek only reads (PEEK-213, ADR 0004). It is the
/// reverse direction of the PEEK-111 export: entries are keyed by the export's
/// opaque event `id`, so a writer can match what it read from
/// `Peek --export --json`.
///
/// Version 1 is a maintained contract. Unknown fields are ignored, so writers
/// may add fields; removing or retyping one needs `schemaVersion: 2`.
struct MeetingContextFile: Equatable {
    static let fileName = "peek-context.json"
    static let supportedSchemaVersion = 1

    /// Limits that keep a large or hostile file from slowing the popover.
    enum Limits {
        static let maxFileBytes = 1_048_576
        static let maxEvents = 1000
        static let maxHeadline = 200
        static let maxSummary = 1200
        static let maxBullets = 6
        static let maxBullet = 300
        static let maxPeople = 25
        static let maxPersonField = 200
        static let maxLinks = 6
    }

    struct Person: Equatable {
        let email: String?
        let name: String?
        let role: String?
        let company: String?
        let note: String?
    }

    struct Link: Equatable {
        let title: String
        let url: URL
    }

    struct Entry: Equatable {
        let id: String
        /// Optional occurrence start; recurring events share one `id`.
        let startAt: Date?
        let headline: String?
        let summary: String?
        let bullets: [String]
        let people: [Person]
        let links: [Link]
    }

    enum DecodeError: Error, Equatable {
        case tooLarge
        case malformed
        case unsupportedVersion(Int)
    }

    let generatedAt: Date?
    let entries: [Entry]

    /// The entry for an event occurrence. An entry with `startAt` matches only
    /// that occurrence (within a minute); one without matches every occurrence,
    /// and an exact occurrence match wins over it.
    func entry(forEventID id: String, start: Date?) -> Entry? {
        let candidates = entries.filter { $0.id == id }
        if let start, let exact = candidates.first(where: { entry in
            entry.startAt.map { abs($0.timeIntervalSince(start)) < 60 } ?? false
        }) {
            return exact
        }
        return candidates.first { $0.startAt == nil }
    }

    static func decode(_ data: Data) throws -> MeetingContextFile {
        guard data.count <= Limits.maxFileBytes else { throw DecodeError.tooLarge }
        let raw: Raw
        do {
            raw = try JSONDecoder().decode(Raw.self, from: data)
        } catch {
            throw DecodeError.malformed
        }
        guard raw.schemaVersion == supportedSchemaVersion else {
            throw DecodeError.unsupportedVersion(raw.schemaVersion)
        }
        let entries = (raw.events ?? []).prefix(Limits.maxEvents).compactMap(entry(from:))
        return MeetingContextFile(generatedAt: raw.generatedAt.flatMap(parseDate), entries: entries)
    }

    // MARK: Mapping

    private static func entry(from raw: Raw.Event) -> Entry? {
        guard let id = raw.id, !id.isEmpty else { return nil }
        return Entry(
            id: id,
            startAt: raw.startAt.flatMap(parseDate),
            headline: clipped(raw.headline, Limits.maxHeadline),
            summary: clipped(raw.summary, Limits.maxSummary),
            bullets: (raw.bullets ?? []).compactMap { clipped($0, Limits.maxBullet) }.prefix(Limits.maxBullets).map { $0 },
            people: (raw.people ?? []).prefix(Limits.maxPeople).map {
                Person(
                    email: clipped($0.email, Limits.maxPersonField),
                    name: clipped($0.name, Limits.maxPersonField),
                    role: clipped($0.role, Limits.maxPersonField),
                    company: clipped($0.company, Limits.maxPersonField),
                    note: clipped($0.note, Limits.maxSummary)
                )
            },
            links: (raw.links ?? []).compactMap(link(from:)).prefix(Limits.maxLinks).map { $0 }
        )
    }

    /// Only https links, so a context file cannot open local files or apps.
    private static func link(from raw: Raw.Link) -> Link? {
        guard let value = raw.url, let url = URL(string: value),
              url.scheme?.lowercased() == "https", url.host != nil else { return nil }
        let title = clipped(raw.title, Limits.maxPersonField) ?? url.host ?? value
        return Link(title: title, url: url)
    }

    private static func clipped(_ value: String?, _ limit: Int) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed.count > limit ? String(trimmed.prefix(limit - 1)) + "…" : trimmed
    }

    /// ISO 8601 with an offset, with or without fractional seconds, matching
    /// what the PEEK-111 export writes.
    static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }

    private struct Raw: Decodable {
        let schemaVersion: Int
        let generatedAt: String?
        let events: [Event]?

        struct Event: Decodable {
            let id: String?
            let startAt: String?
            let headline: String?
            let summary: String?
            let bullets: [String]?
            let people: [Person]?
            let links: [Link]?
        }

        struct Person: Decodable {
            let email: String?
            let name: String?
            let role: String?
            let company: String?
            let note: String?
        }

        struct Link: Decodable {
            let title: String?
            let url: String?
        }
    }
}
