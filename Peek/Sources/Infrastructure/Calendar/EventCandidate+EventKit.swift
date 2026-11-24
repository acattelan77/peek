import EventKit

extension EKEvent: EventCandidate {
    var candidateStartDate: Date? {
        startDate
    }

    var candidateEndDate: Date? {
        endDate
    }

    var candidateTitle: String? {
        title
    }

    var candidateNotes: String? {
        notes
    }

    var candidateIdentity: EventIdentity? {
        let seriesID: String = calendarItemIdentifier
        let occurrence: Date? = (occurrenceDate as Date?) ?? (startDate as Date?)
        guard !seriesID.isEmpty, let occurrence else { return nil }
        return EventIdentity(seriesID: seriesID, occurrenceDate: occurrence, isRecurring: hasRecurrenceRules)
    }

    var currentUserDeclined: Bool {
        guard let attendees = attendees else {
            return false
        }

        for attendee in attendees where attendee.isCurrentUser {
            if attendee.participantStatus == .declined {
                return true
            }
        }

        return false
    }
}
