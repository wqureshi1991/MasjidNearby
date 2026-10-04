import Foundation

enum Prayer: String, Sendable, Hashable, Codable, CaseIterable {
    case fajr
    case dhuhr
    case asr
    case maghrib
    case isha
}

struct PrayerTime: Sendable, Hashable, Codable {
    let adhan: WallClockTime
    /// Congregation time. Nil when the masjid has not set one, and always nil for calculated times.
    let iqamah: WallClockTime?

    init(adhan: WallClockTime, iqamah: WallClockTime? = nil) {
        self.adhan = adhan
        self.iqamah = iqamah
    }
}

enum PrayerTimeSource: String, Sendable, Hashable, Codable {
    /// Typed in by the masjid.
    case manual
    /// Scanned from a timetable and confirmed by the masjid.
    case ocr
    /// Computed from the masjid's location because no schedule was published.
    case calculated
}

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
