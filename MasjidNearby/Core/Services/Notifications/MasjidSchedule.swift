import Foundation

/// A masjid and the days of its schedule saved on the device.
struct MasjidSchedule: Sendable {
    let masjid: Masjid
    let published: [DailyPrayerTimes]
}
