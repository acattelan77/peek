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
