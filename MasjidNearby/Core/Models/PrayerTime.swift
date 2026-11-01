import Foundation

struct PrayerTime: Sendable, Hashable, Codable {
    let adhan: WallClockTime
    /// Congregation time. Nil when the masjid has not set one, and always nil for calculated times.
    let iqamah: WallClockTime?

    init(adhan: WallClockTime, iqamah: WallClockTime? = nil) {
        self.adhan = adhan
        self.iqamah = iqamah
    }
}
