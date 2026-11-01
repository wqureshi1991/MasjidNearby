import Foundation

enum PrayerTimeSource: String, Sendable, Hashable, Codable {
    /// Typed in by the masjid.
    case manual
    /// Scanned from a timetable and confirmed by the masjid.
    case ocr
    /// Computed from the masjid's location because no schedule was published.
    case calculated
}
