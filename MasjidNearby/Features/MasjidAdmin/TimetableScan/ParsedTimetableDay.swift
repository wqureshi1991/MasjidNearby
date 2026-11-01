import Foundation

struct ParsedTimetableDay: Sendable, Equatable {
    let dayOfMonth: Int
    /// Times read for each column. A column that couldn't be read is missing here and flagged.
    let values: [TimetableSlot: WallClockTime]
    /// Columns that needed a character fixed up ("5:4O") or couldn't be read at all.
    let flagged: Set<TimetableSlot>
}
