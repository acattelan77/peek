import Foundation

/// A person as the calendar knows them: what EventKit gives for an attendee.
struct AttendeeInput: Equatable {
    let name: String?
    let email: String?
    let isOrganizer: Bool
    let isCurrentUser: Bool
    /// Rooms and resources are attendees in EventKit but not people to meet.
    let isPerson: Bool
    let response: AttendeeResponse

    init(
        name: String?,
        email: String?,
        isOrganizer: Bool = false,
        isCurrentUser: Bool = false,
        isPerson: Bool = true,
        response: AttendeeResponse = .unknown
    ) {
        self.name = name
        self.email = email
        self.isOrganizer = isOrganizer
        self.isCurrentUser = isCurrentUser
        self.isPerson = isPerson
        self.response = response
    }
}

/// What the user's Contacts know about an email address (PEEK-211).
struct ContactCard: Equatable {
    let givenName: String?
    let fullName: String?
    let jobTitle: String?
    let organization: String?
}

/// Looks up a contact card by email. Implementations must never prompt for
/// permission: they return `nil` until the user has granted Contacts access.
protocol ContactLookup {
    func card(forEmail email: String) -> ContactCard?
}

/// A display-ready person in the meeting-context card.
struct MeetingPerson: Equatable {
    let name: String
    /// Short name for the headline ("Marco"), falling back to `name`.
    let shortName: String
    let role: String?
    let company: String?
    /// Email domain shown when nothing better is known ("northwind.example").
    let domain: String?
    let note: String?
    let isOrganizer: Bool
    let response: AttendeeResponse

    /// "CEO at Northwind", "CEO", "Northwind", "from northwind.example", or nil.
    var descriptor: String? {
        switch (role, company) {
        case let (role?, company?):
            return String(format: NSLocalizedString("%@ at %@", comment: "Attendee role at company, e.g. CEO at Northwind"), role, company)
        case let (role?, nil):
            return role
        case let (nil, company?):
            return company
        case (nil, nil):
            return domain.map { String(format: NSLocalizedString("from %@", comment: "Attendee email domain, e.g. from northwind.example"), $0) }
        }
    }
}

/// Everything the "You're about to meet" card shows. Built from plain values
/// so the rules are testable without EventKit, Contacts or files.
struct MeetingContext: Equatable {
    let headline: String?
    /// True when `headline` came from the context file rather than from the
    /// people Peek found. A writer's headline can be a long sentence (Northwind Notes
    /// sends the proposed goal), so the meeting page keeps the event title as its
    /// title and shows this line at the top of Context instead.
    var headlineIsFromContextFile: Bool = false
    let people: [MeetingPerson]
    let agenda: String?
    /// Context written by another app into the user's context folder (PEEK-213).
    let summary: String?
    let bullets: [String]
    let links: [MeetingContextFile.Link]
    /// When the context file is stale (PEEK-264): its `generatedAt`, so the
    /// meeting page can say "Context from 23 Nov". Nil when fresh or unused.
    var staleContextDate: Date? = nil

    static let empty = MeetingContext(headline: nil, people: [], agenda: nil, summary: nil, bullets: [], links: [])

    var isEmpty: Bool {
        headline == nil && people.isEmpty && agenda == nil && summary == nil && bullets.isEmpty && links.isEmpty
    }

    var hasExternalContext: Bool {
        summary != nil || !bullets.isEmpty || !links.isEmpty
    }

    /// The headline the meeting page shows in its Context section: only one
    /// the context file wrote. Peek's own "You're about to meet…" stays the title.
    var contextFileHeadline: String? {
        headlineIsFromContextFile ? headline : nil
    }

    /// The context bullets the Context section still has to show: those not
    /// already listed under "What to prepare". A brief from the context folder
    /// is made of these same bullets, and showing them twice read as an error.
    func contextBullets(excludingBriefPoints points: [String]) -> [String] {
        let shown = Set(points)
        return bullets.filter { !shown.contains($0) }
    }
}

/// "2 to prepare: Confirm the renewal position" (PEEK-263): how many points
/// from the context file are still open, and the first one. The writer leaves
/// done points out of `bullets`, so every bullet counts. Nil with no bullets.
enum PrepSummary {
    static func text(for bullets: [String], bundle: Bundle = .main) -> String? {
        guard let first = bullets.first else { return nil }
        if bullets.count == 1 {
            return String(format: NSLocalizedString("1 to prepare: %@", bundle: bundle, comment: "Prep count with the first point, one point"), first)
        }
        return String(format: NSLocalizedString("%d to prepare: %@", bundle: bundle, comment: "Prep count with the first point, several points"), bullets.count, first)
    }
}

enum MeetingContextBuilder {
    /// Consumer mail domains say nothing about the company.
    static let personalMailDomains: Set<String> = [
        "gmail.com", "googlemail.com", "outlook.com", "hotmail.com", "hotmail.it", "live.com", "live.it",
        "msn.com", "icloud.com", "me.com", "mac.com", "yahoo.com", "yahoo.it", "aol.com",
        "proton.me", "protonmail.com", "gmx.de", "gmx.net", "web.de", "libero.it", "virgilio.it",
        "orange.fr", "free.fr", "wanadoo.fr", "qq.com", "163.com"
    ]

    static func make(
        attendees: [AttendeeInput],
        notes: String?,
        contacts: ContactLookup?,
        external: MeetingContextFile.Entry?,
        externalStaleSince: Date? = nil
    ) -> MeetingContext {
        let people = makePeople(attendees: attendees, contacts: contacts, external: external?.people ?? [])
        let bullets = external?.bullets ?? []
        return MeetingContext(
            headline: external?.headline ?? headline(for: people),
            headlineIsFromContextFile: external?.headline != nil,
            people: people,
            agenda: InvitationTextCleaner.clean(notes),
            summary: external?.summary,
            bullets: bullets,
            links: external?.links ?? [],
            staleContextDate: external == nil ? nil : externalStaleSince
        )
    }

    /// The people to meet, without the current user, rooms and duplicates.
    /// Context-folder details win over Contacts, which win over the email domain.
    static func makePeople(
        attendees: [AttendeeInput],
        contacts: ContactLookup?,
        external: [MeetingContextFile.Person]
    ) -> [MeetingPerson] {
        var seen = Set<String>()
        var people: [MeetingPerson] = []
        for attendee in attendees where attendee.isPerson && !attendee.isCurrentUser {
            let email = normalizedEmail(attendee.email)
            let dedupeKey = email ?? attendee.name?.lowercased() ?? ""
            guard !dedupeKey.isEmpty, seen.insert(dedupeKey).inserted else { continue }

            let card = email.flatMap { contacts?.card(forEmail: $0) }
            let extra = email.flatMap { address in external.first { normalizedEmail($0.email) == address } }
            // Calendars often put the address in the name field; an address is never a name.
            let calendarName = nonEmpty(attendee.name).flatMap { $0.contains("@") ? nil : $0 }
            let name = nonEmpty(extra?.name) ?? nonEmpty(card?.fullName) ?? calendarName
                ?? email.flatMap(displayName(fromEmail:)) ?? email ?? dedupeKey
            let shortName = nonEmpty(card?.givenName) ?? firstWord(of: name, isEmail: name.contains("@"))
            let domain = email.flatMap(companyDomain(fromEmail:))

            people.append(MeetingPerson(
                name: name,
                shortName: shortName,
                role: nonEmpty(extra?.role) ?? nonEmpty(card?.jobTitle),
                company: nonEmpty(extra?.company) ?? nonEmpty(card?.organization),
                domain: domain,
                note: nonEmpty(extra?.note),
                isOrganizer: attendee.isOrganizer,
                response: attendee.response
            ))
        }
        // People Peek knows something about come first; then keep calendar order.
        let known = people.filter { $0.role != nil || $0.company != nil }
        let unknown = people.filter { $0.role == nil && $0.company == nil }
        return known + unknown
    }

    /// "You're about to meet Marco, CEO at Northwind", "… Marco and Anna",
    /// "… Marco and 3 others". Nil when there is nobody to meet.
    static func headline(for people: [MeetingPerson]) -> String? {
        guard let lead = people.first else { return nil }
        switch people.count {
        case 1:
            if let descriptor = lead.descriptor {
                return String(format: NSLocalizedString("You're about to meet %@, %@", comment: "Meeting headline: one person with role"), lead.shortName, descriptor)
            }
            return String(format: NSLocalizedString("You're about to meet %@", comment: "Meeting headline: one person"), lead.shortName)
        case 2:
            return String(format: NSLocalizedString("You're about to meet %@ and %@", comment: "Meeting headline: two people"), lead.shortName, people[1].shortName)
        default:
            // Only a real role or company earns the long form; an email domain is noise here.
            if lead.role != nil || lead.company != nil, let descriptor = lead.descriptor {
                return String(format: NSLocalizedString("You're about to meet %@, %@, and %d others", comment: "Meeting headline: several people, lead with role"), lead.shortName, descriptor, people.count - 1)
            }
            return String(format: NSLocalizedString("You're about to meet %@ and %d others", comment: "Meeting headline: several people"), lead.shortName, people.count - 1)
        }
    }

    /// "grace.hopper@northwind.example" → "Grace Hopper". Nil when the local part
    /// does not look like a name (digits, role mailboxes such as "info", one letter).
    static func displayName(fromEmail email: String) -> String? {
        guard let at = email.firstIndex(of: "@") else { return nil }
        let local = email[..<at].split(separator: "+").first.map(String.init) ?? ""
        let parts = local.split(whereSeparator: { $0 == "." || $0 == "_" || $0 == "-" }).map(String.init)
        guard !parts.isEmpty, parts.count <= 4,
              parts.allSatisfy({ $0.count >= 2 && $0.allSatisfy(\.isLetter) }) else { return nil }
        if parts.count == 1, roleMailboxes.contains(parts[0].lowercased()) { return nil }
        return parts.map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined(separator: " ")
    }

    static let roleMailboxes: Set<String> = [
        "info", "admin", "support", "hello", "contact", "sales", "office", "team", "noreply", "calendar", "booking"
    ]

    static func normalizedEmail(_ email: String?) -> String? {
        guard var value = email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !value.isEmpty else { return nil }
        if value.hasPrefix("mailto:") { value = String(value.dropFirst("mailto:".count)) }
        return value.contains("@") ? value : nil
    }

    /// The email domain, unless it is a personal mail provider.
    static func companyDomain(fromEmail email: String) -> String? {
        guard let at = email.lastIndex(of: "@") else { return nil }
        let domain = String(email[email.index(after: at)...])
        guard domain.contains("."), !personalMailDomains.contains(domain) else { return nil }
        return domain
    }

    private static func firstWord(of name: String, isEmail: Bool) -> String {
        if isEmail { return name }
        return name.split(separator: " ").first.map(String.init) ?? name
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
