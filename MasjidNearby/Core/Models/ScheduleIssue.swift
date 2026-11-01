import Foundation

enum ScheduleIssue: Sendable, Hashable, CustomStringConvertible {
    /// `earlier` should come before `later` but doesn't.
    case outOfOrder(earlier: String, later: String)
    case iqamahBeforeAdhan(Prayer)
    case iqamahTooLate(Prayer)

    var description: String {
        switch self {
        case .outOfOrder(let earlier, let later):
            "\(earlier) must be before \(later)."
        case .iqamahBeforeAdhan(let prayer):
            "\(prayer.displayName) iqamah is before its adhan."
        case .iqamahTooLate(let prayer):
            "\(prayer.displayName) iqamah is more than \(ScheduleValidator.maximumIqamahDelay) minutes after its adhan."
        }
    }
}
