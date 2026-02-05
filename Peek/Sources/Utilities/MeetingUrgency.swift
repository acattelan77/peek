enum MeetingUrgency: Equatable {
    case critical   // < 2 minutes (pulsing, red)
    case urgent     // 2-10 minutes (orange)
    case normal     // > 10 minutes (default color)

    static func from(minutesUntil: Int) -> MeetingUrgency {
        switch minutesUntil {
        case ..<2:
            return .critical
        case 2..<10:
            return .urgent
        default:
            return .normal
        }
    }
}
