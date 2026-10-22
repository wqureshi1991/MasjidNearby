import Foundation

struct UpcomingPrayer: Sendable, Equatable {
    let prayer: Prayer
    let adhan: Date
    let iqamah: Date?
    /// True when it's tomorrow's Fajr, after tonight's Isha.
    let isTomorrow: Bool
}

/// Turns a day's wall-clock times into real instants and finds the next prayer.
enum NextPrayerFinder {
    /// The first prayer whose adhan is after `now`. After Isha, tomorrow's Fajr
    /// (nil if tomorrow's times aren't known).
    static func next(after now: Date,
                     today: DailyPrayerTimes,
                     tomorrow: DailyPrayerTimes?,
                     in timeZone: TimeZone) -> UpcomingPrayer? {
        if let upcoming = instants(of: today, in: timeZone).first(where: { $0.adhan > now }) {
            return upcoming
        }
        guard let tomorrow else { return nil }
        let fajr = instant(of: .fajr, in: tomorrow, timeZone: timeZone)
        return UpcomingPrayer(prayer: fajr.prayer, adhan: fajr.adhan, iqamah: fajr.iqamah, isTomorrow: true)
    }

    /// Each prayer's adhan and iqamah instants, in order.
    /// An Isha earlier than Maghrib is after midnight, so it falls on the next calendar day.
    static func instants(of times: DailyPrayerTimes, in timeZone: TimeZone) -> [UpcomingPrayer] {
        Prayer.allCases.map { instant(of: $0, in: times, timeZone: timeZone) }
    }

    private static func instant(of prayer: Prayer, in times: DailyPrayerTimes, timeZone: TimeZone) -> UpcomingPrayer {
        let time = times[prayer]
        let isAfterMidnight = prayer == .isha && time.adhan < times.maghrib.adhan
        let day = isAfterMidnight ? times.day.adding(days: 1) : times.day
        let adhan = time.adhan.instant(on: day, in: timeZone)
        let iqamah = time.iqamah.map { adhan.addingTimeInterval(Double(time.adhan.minutes(until: $0) * 60)) }
        return UpcomingPrayer(prayer: prayer, adhan: adhan, iqamah: iqamah, isTomorrow: false)
    }
}
