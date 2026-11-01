import Foundation

/// Shape of a `masjids/{id}/schedule/{yyyy-MM-dd}` document.
enum ScheduleDayDTO {
    enum Key {
        static let day = "day"
        static let sunrise = "sunrise"
        static let source = "source"
        static let adhan = "adhan"
        static let iqamah = "iqamah"
        static let updatedAt = "updatedAt"
    }

    static func data(for times: DailyPrayerTimes) -> [String: Any] {
        var data: [String: Any] = [
            Key.day: times.day.key,
            Key.sunrise: times.sunrise.description,
            Key.source: times.source.rawValue,
        ]
        for prayer in Prayer.allCases {
            var entry = [Key.adhan: times[prayer].adhan.description]
            if let iqamah = times[prayer].iqamah {
                entry[Key.iqamah] = iqamah.description
            }
            data[prayer.rawValue] = entry
        }
        return data
    }

    /// `updatedAt` comes from the document's server timestamp, which only the Firestore layer can read.
    static func times(from data: [String: Any], updatedAt: Date? = nil) throws -> DailyPrayerTimes {
        guard let day = (data[Key.day] as? String).flatMap({ CalendarDay(key: $0) }) else {
            throw RepositoryError.invalidData("schedule day has no valid date")
        }
        guard let sunrise = (data[Key.sunrise] as? String).flatMap({ WallClockTime($0) }) else {
            throw RepositoryError.invalidData("schedule \(day.key) has no valid sunrise")
        }
        let source = (data[Key.source] as? String).flatMap(PrayerTimeSource.init(rawValue:)) ?? .manual

        func prayerTime(_ prayer: Prayer) throws -> PrayerTime {
            guard let entry = data[prayer.rawValue] as? [String: Any],
                  let adhan = (entry[Key.adhan] as? String).flatMap({ WallClockTime($0) })
            else { throw RepositoryError.invalidData("schedule \(day.key) has no valid \(prayer.displayName) time") }
            return PrayerTime(adhan: adhan, iqamah: (entry[Key.iqamah] as? String).flatMap { WallClockTime($0) })
        }

        return DailyPrayerTimes(
            day: day,
            fajr: try prayerTime(.fajr),
            sunrise: sunrise,
            dhuhr: try prayerTime(.dhuhr),
            asr: try prayerTime(.asr),
            maghrib: try prayerTime(.maghrib),
            isha: try prayerTime(.isha),
            source: source,
            updatedAt: updatedAt
        )
    }
}
