import Foundation

/// A time of day as read off a clock on the masjid's wall: "05:42".
/// It only becomes a `Date` when combined with a `CalendarDay` and the masjid's time zone.
struct WallClockTime: Sendable, Hashable, Comparable, CustomStringConvertible {
    let hour: Int
    let minute: Int

    init?(hour: Int, minute: Int) {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        self.hour = hour
        self.minute = minute
    }

    /// Parses strict 24-hour "HH:mm".
    init?(_ string: String) {
        let parts = string.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              parts[0].count == 2, parts[1].count == 2,
              parts.allSatisfy({ $0.utf8.allSatisfy { (0x30...0x39).contains($0) } }),
              let hour = Int(parts[0]), let minute = Int(parts[1])
        else { return nil }
        self.init(hour: hour, minute: minute)
    }

    /// Wraps any minute count onto a 24-hour clock, so 1445 becomes 00:05 and -5 becomes 23:55.
    init(wrappingMinutesSinceMidnight minutes: Int) {
        let wrapped = ((minutes % 1_440) + 1_440) % 1_440
        hour = wrapped / 60
        minute = wrapped % 60
    }

    var minutesSinceMidnight: Int { hour * 60 + minute }

    /// "HH:mm". This is the stored format.
    var description: String {
        String(format: "%02d:%02d", hour, minute)
    }

    /// The instant this time occurs on `day` in `timeZone`.
    /// Returns nil for a time that does not exist that day (inside a DST spring-forward gap).
    func date(on day: CalendarDay, in timeZone: TimeZone) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(year: day.year, month: day.month, day: day.day, hour: hour, minute: minute)
        guard let date = calendar.date(from: components) else { return nil }
        let resolved = calendar.dateComponents([.hour, .minute], from: date)
        guard resolved.hour == hour, resolved.minute == minute else { return nil }
        return date
    }

    static func < (lhs: WallClockTime, rhs: WallClockTime) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }
}

extension WallClockTime: Codable {
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let time = WallClockTime(string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected HH:mm, got \(string)")
        }
        self = time
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
