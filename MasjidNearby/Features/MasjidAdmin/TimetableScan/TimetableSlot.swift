import Foundation

/// One column of a printed monthly timetable.
enum TimetableSlot: Sendable, Hashable {
    case adhan(Prayer)
    case iqamah(Prayer)
    case sunrise

    var prayer: Prayer? {
        switch self {
        case .adhan(let prayer), .iqamah(let prayer): prayer
        case .sunrise: nil
        }
    }

    var displayName: String {
        switch self {
        case .adhan(let prayer): "\(prayer.displayName) adhan"
        case .iqamah(let prayer): "\(prayer.displayName) iqamah"
        case .sunrise: "Sunrise"
        }
    }
}
