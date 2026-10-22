import Foundation

/// Clearly-labelled sample masjids around San Jose, so the user side can be demoed
/// before Firebase is connected. Used only when `GoogleService-Info.plist` is missing.
enum DemoData {
    static func repository(now: Date = Date()) -> MockMasjidRepository {
        let timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
        let downtown = masjid(id: "sample-downtown", name: "Sample Masjid – Downtown San Jose",
                              address: "Downtown San Jose, CA (sample data)",
                              latitude: 37.3347, longitude: -121.8899)
        let santaClara = masjid(id: "sample-santa-clara", name: "Sample Masjid – Santa Clara",
                                address: "Santa Clara, CA (sample data)",
                                latitude: 37.3541, longitude: -121.9552)
        let milpitas = masjid(id: "sample-milpitas", name: "Sample Masjid – Milpitas",
                              address: "Milpitas, CA (sample data)",
                              latitude: 37.4323, longitude: -121.8996)

        // Only the downtown masjid publishes times; the others show calculated times.
        let today = CalendarDay(date: now, in: timeZone)
        let calculator = AstronomicalPrayerTimeCalculator()
        var published: [DailyPrayerTimes] = []
        for offset in -1..<30 {
            let day = today.adding(days: offset)
            do {
                let calculated = try calculator.times(on: day, at: downtown.coordinates, in: timeZone,
                                                      parameters: downtown.calculation)
                published.append(withIqamah(calculated))
            } catch {
                continue
            }
        }

        return MockMasjidRepository(
            masjids: [downtown, santaClara, milpitas],
            published: [downtown.id: published]
        )
    }

    private static func masjid(id: String, name: String, address: String,
                               latitude: Double, longitude: Double) -> Masjid {
        Masjid(
            id: id,
            name: name,
            address: address,
            coordinates: Coordinates(latitude: latitude, longitude: longitude),
            timeZoneIdentifier: "America/Los_Angeles",
            calculation: CalculationParameters(method: .isna),
            jumuah: [
                JumuahSlot(khutbah: WallClockTime(wrappingMinutesSinceMidnight: 13 * 60 + 15),
                           iqamah: WallClockTime(wrappingMinutesSinceMidnight: 13 * 60 + 45)),
            ],
            isVerified: true
        )
    }

    /// Adds typical iqamah gaps to calculated adhan times and marks the day as published.
    private static func withIqamah(_ times: DailyPrayerTimes) -> DailyPrayerTimes {
        func prayer(_ time: PrayerTime, gap: Int) -> PrayerTime {
            PrayerTime(adhan: time.adhan, iqamah: time.adhan.adding(minutes: gap))
        }
        return DailyPrayerTimes(
            day: times.day,
            fajr: prayer(times.fajr, gap: 20),
            sunrise: times.sunrise,
            dhuhr: prayer(times.dhuhr, gap: 15),
            asr: prayer(times.asr, gap: 15),
            maghrib: prayer(times.maghrib, gap: 5),
            isha: prayer(times.isha, gap: 15),
            source: .manual
        )
    }
}
