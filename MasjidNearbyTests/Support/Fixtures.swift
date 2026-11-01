import Foundation
import Testing
@testable import MasjidNearby

enum Fixtures {
    static let sanJose = Coordinates(latitude: 37.3382, longitude: -121.8863)

    static func time(_ string: String) -> WallClockTime {
        WallClockTime(string) ?? WallClockTime(wrappingMinutesSinceMidnight: 0)
    }

    static func masjid(id: String = "m1", isVerified: Bool = false) -> Masjid {
        Masjid(
            id: id,
            name: "Masjid Al-Noor",
            address: "1 Main St, San Jose, CA",
            coordinates: sanJose,
            timeZoneIdentifier: "America/Los_Angeles",
            calculation: CalculationParameters(method: .isna, asrMadhab: .hanafi),
            jumuah: [JumuahSlot(khutbah: time("13:15"), iqamah: time("13:45")), JumuahSlot(khutbah: time("14:30"))],
            isVerified: isVerified
        )
    }

    static func day(_ key: String) -> CalendarDay {
        CalendarDay(key: key) ?? CalendarDay(julianDayNumber: 2_440_588)
    }

    static func times(on key: String, fajr: String = "05:53", fajrIqamah: String? = nil,
                      dhuhr: String = "12:57", source: PrayerTimeSource = .calculated) -> DailyPrayerTimes {
        DailyPrayerTimes(
            day: day(key),
            fajr: PrayerTime(adhan: time(fajr), iqamah: fajrIqamah.map(time)),
            sunrise: time("07:04"),
            dhuhr: PrayerTime(adhan: time(dhuhr)),
            asr: PrayerTime(adhan: time("16:17")),
            maghrib: PrayerTime(adhan: time("18:49")),
            isha: PrayerTime(adhan: time("20:01")),
            source: source
        )
    }
}
