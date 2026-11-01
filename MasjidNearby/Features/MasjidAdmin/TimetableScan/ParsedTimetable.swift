import Foundation

struct ParsedTimetable: Sendable, Equatable {
    let layout: TimetableLayout
    /// Sorted by day of month; each day appears once.
    let days: [ParsedTimetableDay]
}
