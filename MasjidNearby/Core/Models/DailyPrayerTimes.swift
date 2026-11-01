import Foundation

/// One day of times at one masjid, in that masjid's wall-clock time.
/// An Isha earlier than Fajr means it falls after midnight (high latitudes in summer).
struct DailyPrayerTimes: Sendable, Hashable, Codable {
    let day: CalendarDay
    let fajr: PrayerTime
    let sunrise: WallClockTime
    let dhuhr: PrayerTime
    let asr: PrayerTime
    let maghrib: PrayerTime
    let isha: PrayerTime
    let source: PrayerTimeSource
    /// When the masjid last published this day. Nil for calculated or unsaved times.
    var updatedAt: Date? = nil

    subscript(prayer: Prayer) -> PrayerTime {
        switch prayer {
        case .fajr: fajr
        case .dhuhr: dhuhr
        case .asr: asr
        case .maghrib: maghrib
        case .isha: isha
        }
    }
}
