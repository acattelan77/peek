import Foundation

/// Turns event notes into a readable agenda by removing the boilerplate that
/// conferencing providers paste into invitations: join instructions, meeting
/// IDs and passcodes, dial-in numbers, SIP and H.323 details, and the Google
/// Meet and Microsoft Teams blocks. Pure text in, text out (PEEK-212).
enum InvitationTextCleaner {
    /// Notes longer than this are cut before cleaning; invitations rarely carry
    /// agenda text past it and the regexes stay cheap.
    static let maxInputLength = 8000

    /// Returns the cleaned agenda, or `nil` when nothing but boilerplate is left.
    static func clean(_ notes: String?) -> String? {
        guard let notes, !notes.isEmpty else { return nil }
        var text = String(notes.prefix(maxInputLength))
        if looksLikeHTML(text) { text = plainText(fromHTML: text) }
        text = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        text = removeDelimitedBlocks(text)

        var kept: [String] = []
        var inDialInList = false
        for rawLine in text.components(separatedBy: "\n") {
            let original = rawLine.trimmingCharacters(in: .whitespaces)
            // Zoom lists dial-in numbers as "• +1 646 …"; match without the bullet.
            let line = original.trimmingCharacters(in: CharacterSet(charactersIn: "•·*- \t"))
            if line.isEmpty && !original.isEmpty { continue }
            if line.isEmpty {
                inDialInList = false
                kept.append("")
                continue
            }
            if startsDialInList(line) {
                inDialInList = true
                continue
            }
            if inDialInList && (isPhoneLine(line, requireInternationalPrefix: false) || isNetworkAddressLine(line)) { continue }
            inDialInList = false
            if isBoilerplate(line) || isPhoneLine(line, requireInternationalPrefix: true)
                || isNetworkAddressLine(line) || isOnlyJoinLink(line) { continue }
            kept.append(original)
        }

        let collapsed = collapseBlankLines(kept).trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed.isEmpty ? nil : collapsed
    }

    // MARK: Blocks

    /// Google Meet wraps its block in `-::~:~::~:~...` lines; Teams and Outlook
    /// wrap theirs in long underscore rules. A Teams block is removed only when
    /// it mentions Teams, so an agenda the organizer underlined stays.
    private static func removeDelimitedBlocks(_ text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        lines = removeBlocks(in: lines, isDelimiter: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("-::~") }, mustMention: nil)
        lines = removeBlocks(in: lines, isDelimiter: isUnderscoreRule, mustMention: "teams")
        return lines.joined(separator: "\n")
    }

    private static func removeBlocks(in lines: [String], isDelimiter: (String) -> Bool, mustMention: String?) -> [String] {
        let delimiterIndexes = lines.indices.filter { isDelimiter(lines[$0]) }
        guard delimiterIndexes.count >= 2 else { return lines }
        var remove = IndexSet()
        var index = 0
        while index + 1 < delimiterIndexes.count {
            let range = delimiterIndexes[index]...delimiterIndexes[index + 1]
            let body = lines[range].joined(separator: " ").lowercased()
            if mustMention == nil || body.contains(mustMention!) {
                remove.insert(integersIn: range)
                index += 2
            } else {
                index += 1
            }
        }
        return lines.indices.filter { !remove.contains($0) }.map { lines[$0] }
    }

    private static func isUnderscoreRule(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 10 && trimmed.allSatisfy { $0 == "_" }
    }

    // MARK: Lines

    private static let boilerplatePatterns: [NSRegularExpression] = [
        "^join (the )?(zoom|webex|teams|google meet|microsoft teams)? ?meeting\\b",
        "^join with google meet\\b",
        "^join by (phone|sip|h\\.323|video system)\\b",
        "^join on your computer",
        "^(or )?click here to join",
        "^(meeting|webinar|conference) (id|number)\\s*[:#]",
        "^(passcode|password|pwd|pin|access code|meeting password)\\s*[:#]",
        "^(one tap mobile|dial by your location|dial-in|dial in|find your local number|more phone numbers|join by phone)\\b",
        "^find your local number",
        "^download teams\\b",
        "^learn more( about teams)?\\b",
        "^meeting options\\b",
        "^need help\\?",
        "^for organizers\\s*:",
        "^(microsoft teams|zoom) meeting$",
        "^you're invited to (a|join) ",
        "^.* is inviting you to a scheduled zoom meeting\\.?$",
        "^invitation from google calendar",
        "^you are receiving this (email|courtesy)",
        "^forwarding this invitation",
        "^learn more about meet at",
        "^view all guest info",
        "^reply for .* view",
        "^-{3,}$",
        "^\\*{3,}$"
    ].compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }

    private static func isBoilerplate(_ line: String) -> Bool {
        let range = NSRange(line.startIndex..., in: line)
        return boilerplatePatterns.contains { $0.firstMatch(in: line, options: [], range: range) != nil }
    }

    private static func startsDialInList(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.hasPrefix("one tap mobile") || lower.hasPrefix("dial by your location")
            || lower.hasPrefix("join by sip") || lower.hasPrefix("join by h.323")
    }

    private static let phonePattern = try? NSRegularExpression(
        pattern: "^(tel:)?\\+?\\(?\\d[\\d\\s().\\-]{6,}\\d(,,+[\\d#*]+)*[#*]?(\\s*(\\(|-|–|·|,)?\\s*[\\p{L} .,()'-]{0,40}\\)?)?$",
        options: []
    )

    /// A dial-in line: a phone number, optionally followed by a short place
    /// name ("+39 069 480 6488 Italy", "+1 646 558 8656 US (New York)").
    /// Outside a dial-in list only `+` or `tel:` numbers count, so a date or a
    /// figure in the agenda ("2026-11-23", "1.250.000") is kept.
    static func isPhoneLine(_ line: String, requireInternationalPrefix: Bool) -> Bool {
        guard let phonePattern else { return false }
        if requireInternationalPrefix && !(line.hasPrefix("+") || line.lowercased().hasPrefix("tel:")) { return false }
        guard line.filter(\.isNumber).count >= 8 else { return false }
        let range = NSRange(line.startIndex..., in: line)
        return phonePattern.firstMatch(in: line, options: [], range: range) != nil
    }

    private static let networkAddressPattern = try? NSRegularExpression(
        pattern: "^(\\d{1,3}\\.){3}\\d{1,3}(\\s*\\(.*\\))?$|^\\d+@[\\w.-]+$",
        options: []
    )

    private static func isNetworkAddressLine(_ line: String) -> Bool {
        guard let networkAddressPattern else { return false }
        let range = NSRange(line.startIndex..., in: line)
        return networkAddressPattern.firstMatch(in: line, options: [], range: range) != nil
    }

    /// A line holding nothing but a trusted join link (the Join button covers it).
    private static func isOnlyJoinLink(_ line: String) -> Bool {
        let stripped = line.trimmingCharacters(in: CharacterSet(charactersIn: "<>()[] "))
        guard !stripped.contains(" "), let url = URL(string: stripped) else { return false }
        return MeetingURLDetector.isURLSafe(url)
    }

    private static func collapseBlankLines(_ lines: [String]) -> String {
        var result: [String] = []
        for line in lines {
            if line.isEmpty, result.last?.isEmpty ?? true { continue }
            result.append(line)
        }
        return result.joined(separator: "\n")
    }

    // MARK: HTML

    private static func looksLikeHTML(_ text: String) -> Bool {
        text.range(of: "<(br|p|div|a|span|b|i|ul|li)[\\s/>]", options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Minimal HTML to text: line breaks for block tags, link targets kept,
    /// other tags dropped, common entities decoded.
    static func plainText(fromHTML html: String) -> String {
        var text = html
        let replacements: [(String, String)] = [
            ("<br\\s*/?>", "\n"),
            ("</(p|div|li|tr|h[1-6])>", "\n"),
            ("<li[^>]*>", "• "),
            ("<a [^>]*href=\"([^\"]*)\"[^>]*>([^<]*)</a>", "$2 $1"),
            ("<[^>]+>", "")
        ]
        for (pattern, template) in replacements {
            text = text.replacingOccurrences(of: pattern, with: template, options: [.regularExpression, .caseInsensitive])
        }
        let entities = ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&apos;": "'"]
        for (entity, value) in entities {
            text = text.replacingOccurrences(of: entity, with: value)
        }
        return text
    }
}
