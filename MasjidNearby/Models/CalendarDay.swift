import Foundation

/// A Gregorian calendar date with no time and no time zone.
/// Schedules are keyed by this ("2026-10-02"), never by `Date`.
struct CalendarDay: Sendable, Hashable, Comparable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    init?(year: Int, month: Int, day: Int) {
        guard (1...9999).contains(year),
              (1...12).contains(month),
              (1...Self.daysInMonth(month, year: year)).contains(day)
        else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    /// Parses "yyyy-MM-dd".
    init?(key: String) {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.utf8.allSatisfy { (0x30...0x39).contains($0) } }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// The calendar date that `date` falls on in `timeZone`.
    init(date: Date, in timeZone: TimeZone) {
        let localSeconds = date.timeIntervalSince1970 + Double(timeZone.secondsFromGMT(for: date))
        let daysSinceEpoch = Int((localSeconds / 86_400).rounded(.down))
        self.init(julianDayNumber: Self.epochJulianDayNumber + daysSinceEpoch)
    }

    /// Inverse of `julianDayNumber`.
    init(julianDayNumber: Int) {
        let a = julianDayNumber + 32_044
        let b = (4 * a + 3) / 146_097
        let c = a - 146_097 * b / 4
        let d = (4 * c + 3) / 1_461
        let e = c - 1_461 * d / 4
        let m = (5 * e + 2) / 153
        day = e - (153 * m + 2) / 5 + 1
        month = m + 3 - 12 * (m / 10)
        year = 100 * b + d - 4_800 + m / 10
    }

    /// "yyyy-MM-dd". Used as the Firestore document ID for a day's schedule.
    var key: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    var description: String { key }

    /// Julian Day Number: a continuous day count, so date arithmetic needs no `Calendar`.
    var julianDayNumber: Int {
        let a = (14 - month) / 12
        let y = year + 4_800 - a
        let m = month + 12 * a - 3
        return day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32_045
    }

    /// Midnight UTC at the start of this date.
    var startOfDayUTC: Date {
        Date(timeIntervalSince1970: Double(julianDayNumber - Self.epochJulianDayNumber) * 86_400)
    }

    func adding(days: Int) -> CalendarDay {
        CalendarDay(julianDayNumber: julianDayNumber + days)
    }

    static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// Julian Day Number of 1970-01-01.
    private static let epochJulianDayNumber = 2_440_588

    private static func daysInMonth(_ month: Int, year: Int) -> Int {
        switch month {
        case 4, 6, 9, 11:
            return 30
        case 2:
            let isLeap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
            return isLeap ? 29 : 28
        default:
            return 31
        }
    }
}

extension CalendarDay: Codable {
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let key = try container.decode(String.self)
        guard let day = CalendarDay(key: key) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected yyyy-MM-dd, got \(key)")
        }
        self = day
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(key)
    }
}
