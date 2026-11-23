import Foundation
import CryptoKit

/// Where a brief came from. Shown next to the brief, so the user always knows
/// whether a model wrote it and whether anything left the Mac.
enum BriefSource: String, Codable, Equatable {
    /// Written by another app into the context file; no model was called.
    case contextFolder
    /// Apple's on-device model (Foundation Models); nothing left the Mac.
    case onDevice
    /// A cloud model the user opted into.
    case cloud
}

/// A three-to-five point "what to prepare" brief for one meeting (phase 3).
struct MeetingBrief: Codable, Equatable {
    let points: [String]
    let source: BriefSource
    let generatedAt: Date
    /// Hash of the inputs; a changed event gets a new brief (PEEK-224).
    let fingerprint: String

    /// The hero row shows at most this many points; the expanded row shows all.
    static let heroPointLimit = 3
}

/// The only meeting fields a brief engine ever sees. Emails, locations, URLs,
/// calendar names and attendee responses are left out on purpose, and the
/// consent screen lists exactly these fields (PEEK-223).
struct BriefInput: Equatable {
    let title: String
    let start: Date
    let people: [Person]
    let agenda: String?
    let contextSummary: String?
    let contextPoints: [String]

    struct Person: Equatable {
        let name: String
        let descriptor: String?
        let note: String?
    }

    static let maxAgendaLength = 1500
    static let maxPeople = 8

    init(title: String, start: Date, people: [Person], agenda: String?, contextSummary: String?, contextPoints: [String]) {
        self.title = title
        self.start = start
        self.people = Array(people.prefix(Self.maxPeople))
        self.agenda = agenda.map { String($0.prefix(Self.maxAgendaLength)) }
        self.contextSummary = contextSummary
        self.contextPoints = contextPoints
    }

    init(title: String?, start: Date, context: MeetingContext) {
        self.init(
            title: title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                ?? NSLocalizedString("Untitled Event", comment: "Fallback title for untitled events"),
            start: start,
            people: context.people.map { Person(name: $0.name, descriptor: $0.descriptor, note: $0.note) },
            agenda: context.agenda,
            contextSummary: context.summary,
            contextPoints: context.bullets
        )
    }

    /// A brief needs something to work with beyond the title.
    var hasSubstance: Bool {
        !people.isEmpty || agenda != nil || contextSummary != nil || !contextPoints.isEmpty
    }
}

enum BriefPrompt {
    static let maxPoints = 5

    /// System instructions. `language` is an English language name ("Italian").
    static func instructions(language: String) -> String {
        """
        You help a busy professional prepare for a meeting that starts soon.
        Write 3 to 5 short points about what to prepare, check, bring or decide.
        Use only the facts given. Do not invent names, numbers, history or relationships.
        If the facts are thin, give fewer points.
        Put each point on its own line starting with "- ". No title, introduction or closing.
        Write in \(language).
        """
    }

    static func prompt(for input: BriefInput, now: Date = Date()) -> String {
        var lines = ["Meeting: \(input.title)"]
        let minutes = Int(input.start.timeIntervalSince(now) / 60)
        if minutes >= 0 {
            lines.append("Starts in: \(minutes) minutes")
        }
        if !input.people.isEmpty {
            lines.append("People:")
            for person in input.people {
                var line = "- \(person.name)"
                if let descriptor = person.descriptor { line += ", \(descriptor)" }
                if let note = person.note { line += ". Note: \(note)" }
                lines.append(line)
            }
        }
        if let agenda = input.agenda {
            lines.append("Agenda and notes:")
            lines.append(agenda)
        }
        if input.contextSummary != nil || !input.contextPoints.isEmpty {
            lines.append("Background:")
            if let summary = input.contextSummary { lines.append(summary) }
            lines.append(contentsOf: input.contextPoints.map { "- \($0)" })
        }
        return lines.joined(separator: "\n")
    }

    /// Stable across launches, unlike `hashValue`. The start time is part of
    /// the input, so the countdown line does not change the fingerprint.
    static func fingerprint(for input: BriefInput, source: BriefSource) -> String {
        let material = [
            source.rawValue,
            input.title,
            String(Int(input.start.timeIntervalSince1970)),
            input.people.map { [$0.name, $0.descriptor ?? "", $0.note ?? ""].joined(separator: "|") }.joined(separator: ";"),
            input.agenda ?? "",
            input.contextSummary ?? "",
            input.contextPoints.joined(separator: ";")
        ].joined(separator: "\n")
        let digest = SHA256.hash(data: Data(material.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

enum BriefParser {
    static let maxPointLength = 220

    /// Turns model output into at most five clean points: list markers and
    /// numbering removed, headings and empty lines dropped.
    static func points(from text: String) -> [String] {
        var points: [String] = []
        for rawLine in text.components(separatedBy: .newlines) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            line = line.replacingOccurrences(of: "^([-•*–]|\\d+[.)])\\s*", with: "", options: .regularExpression)
            line = line.replacingOccurrences(of: "**", with: "")
            line = line.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasSuffix(":") else { continue }
            if line.count > maxPointLength {
                line = String(line.prefix(maxPointLength - 1)) + "…"
            }
            points.append(line)
            if points.count == BriefPrompt.maxPoints { break }
        }
        return points
    }
}

enum BriefPolicy {
    /// How long before the start a brief is prepared automatically.
    static let leadTime: TimeInterval = 15 * 60

    /// Meetings that get a brief: timed, not declined, with something to work
    /// with, and not matching a keyword the user excluded.
    static func isEligible(
        input: BriefInput,
        notes: String?,
        isAllDay: Bool,
        isDeclined: Bool,
        excludedKeywords: [String]
    ) -> Bool {
        guard !isAllDay, !isDeclined, input.hasSubstance else { return false }
        let haystack = (input.title + "\n" + (notes ?? "")).lowercased()
        return !excludedKeywords.contains { haystack.contains($0) }
    }

    static func isDue(start: Date, now: Date = Date()) -> Bool {
        let remaining = start.timeIntervalSince(now)
        return remaining <= leadTime && remaining > -5 * 60
    }

    /// A brief written by another app into the context file, when it has one.
    static func contextFolderBrief(for input: BriefInput, generatedAt: Date) -> MeetingBrief? {
        guard !input.contextPoints.isEmpty else { return nil }
        return MeetingBrief(
            points: Array(input.contextPoints.prefix(BriefPrompt.maxPoints)),
            source: .contextFolder,
            generatedAt: generatedAt,
            fingerprint: BriefPrompt.fingerprint(for: input, source: .contextFolder)
        )
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
