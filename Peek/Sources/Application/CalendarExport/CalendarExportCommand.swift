import EventKit
import Foundation

enum CalendarExportCommand: Equatable {
    case help
    case export(CalendarExportRequest)
}

struct CalendarExportRequest: Equatable {
    let fromDays: Int
    let toDays: Int
}

enum CalendarExportCommandLine {
    static let usage = """
    Usage: Peek --export --from <signed-days> --to <signed-days> --json

    Export selected local calendars as Calendar Export JSON schema v1. The date
    range starts at local midnight <signed-days> from today and ends exclusively
    at local midnight one day after <signed-days> from today.
    """

    enum ParseResult: Equatable {
        case notRequested
        case command(CalendarExportCommand)
        case failure(String)
    }

    static func parse(arguments: [String]) -> ParseResult {
        guard !arguments.isEmpty else { return .notRequested }
        if arguments == ["--help"] { return .command(.help) }
        guard arguments.first == "--export" else {
            return .failure("Unknown command.\n\n\(usage)")
        }

        var fromDays: Int?
        var toDays: Int?
        var hasJSON = false
        var index = 1
        while index < arguments.count {
            switch arguments[index] {
            case "--json":
                guard !hasJSON else { return .failure("--json may only be provided once.\n\n\(usage)") }
                hasJSON = true
                index += 1
            case "--from", "--to":
                let option = arguments[index]
                guard index + 1 < arguments.count, let value = Int(arguments[index + 1]) else {
                    return .failure("\(option) requires a signed whole number of days.\n\n\(usage)")
                }
                if option == "--from" {
                    guard fromDays == nil else { return .failure("--from may only be provided once.\n\n\(usage)") }
                    fromDays = value
                } else {
                    guard toDays == nil else { return .failure("--to may only be provided once.\n\n\(usage)") }
                    toDays = value
                }
                index += 2
            default:
                return .failure("Unknown option: \(arguments[index]).\n\n\(usage)")
            }
        }

        guard hasJSON, let fromDays, let toDays else {
            return .failure("--export requires --from, --to, and --json.\n\n\(usage)")
        }
        guard fromDays <= toDays else {
            return .failure("--from must not be later than --to.\n\n\(usage)")
        }
        return .command(.export(CalendarExportRequest(fromDays: fromDays, toDays: toDays)))
    }
}

struct CalendarExportWindow: Equatable {
    let from: Date
    let toExclusive: Date

    static func make(
        request: CalendarExportRequest,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CalendarExportWindow? {
        let startOfToday = calendar.startOfDay(for: now)
        guard let from = calendar.date(byAdding: .day, value: request.fromDays, to: startOfToday),
              let inclusiveEndDay = calendar.date(byAdding: .day, value: request.toDays, to: startOfToday),
              let toExclusive = calendar.date(byAdding: .day, value: 1, to: inclusiveEndDay) else {
            return nil
        }
        return CalendarExportWindow(from: from, toExclusive: toExclusive)
    }
}

enum CalendarExportCalendarSelection {
    static let enabledCalendarIDsKey = "enabledCalendarIDs"
    static let hasCustomCalendarSelectionKey = "hasCustomCalendarSelection"

    static func resolve(
        allCalendars: [EKCalendar],
        preferences: any PreferencesStoring
    ) -> [EKCalendar] {
        guard let savedIDs = preferences.array(forKey: enabledCalendarIDsKey) as? [String] else {
            return allCalendars
        }
        let hasCustomSelection = preferences.object(forKey: hasCustomCalendarSelectionKey) as? Bool ?? true
        if savedIDs.isEmpty {
            return hasCustomSelection ? [] : allCalendars
        }
        let enabledIDs = Set(savedIDs)
        return allCalendars.filter { enabledIDs.contains($0.calendarIdentifier) }
    }
}

enum CalendarExportServiceError: LocalizedError {
    case calendarAccessRequired
    case invalidWindow
    case eventStore(Error)

    var errorDescription: String? {
        switch self {
        case .calendarAccessRequired:
            return "Calendar Full Access is required. Grant Peek access in System Settings > Privacy & Security > Calendars, then run the export again."
        case .invalidWindow:
            return "Unable to calculate the requested local calendar window."
        case let .eventStore(error):
            return "Calendar export failed: \(error.localizedDescription)"
        }
    }
}

struct CalendarExportService {
    let eventStore: any CalendarEventStoring
    let preferences: any PreferencesStoring
    let calendar: Calendar
    let now: () -> Date

    init(
        eventStore: any CalendarEventStoring = EventKitCalendarEventStore(),
        preferences: any PreferencesStoring = UserDefaults.standard,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.eventStore = eventStore
        self.preferences = preferences
        self.calendar = calendar
        self.now = now
    }

    func makePayload(request: CalendarExportRequest) throws -> CalendarExportPayload {
        guard hasCalendarAccess else { throw CalendarExportServiceError.calendarAccessRequired }
        guard let window = CalendarExportWindow.make(request: request, now: now(), calendar: calendar) else {
            throw CalendarExportServiceError.invalidWindow
        }

        let allCalendars = eventStore.calendars(for: .event)
        let selectedCalendars = CalendarExportCalendarSelection.resolve(
            allCalendars: allCalendars,
            preferences: preferences
        )
        let events: [EKEvent]
        if selectedCalendars.isEmpty {
            events = []
        } else {
            let predicate = eventStore.predicateForEvents(
                withStart: window.from,
                end: window.toExclusive,
                calendars: selectedCalendars
            )
            do {
                events = try eventStore.events(matching: predicate)
            } catch {
                throw CalendarExportServiceError.eventStore(error)
            }
        }

        let intersectingEvents = events.filter { event in
            event.startDate < window.toExclusive && event.endDate > window.from
        }
        return CalendarExportPayload.make(
            generatedAt: now(),
            timeZone: calendar.timeZone,
            window: window,
            events: intersectingEvents
        )
    }

    private var hasCalendarAccess: Bool {
        let status = eventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            return status == .fullAccess || status == .authorized
        }
        return status == .authorized
    }
}

enum CalendarExportRunner {
    static func execute(_ request: CalendarExportRequest) -> Result<Data, Error> {
        do {
            let payload = try CalendarExportService().makePayload(request: request)
            return .success(try payload.encodedJSON())
        } catch {
            return .failure(error)
        }
    }
}
