import Foundation

/// Shape of a `masjids/{id}` Firestore document. Pure Swift, so it is testable without Firebase.
///
/// Admin UIDs, verification and timestamps are written by the repository, not here:
/// they are not editable details.
enum MasjidDTO {
    enum Key {
        static let name = "name"
        static let address = "address"
        static let latitude = "latitude"
        static let longitude = "longitude"
        static let geohash = "geohash"
        static let timeZone = "timeZone"
        static let calculationMethod = "calculationMethod"
        static let asrMadhab = "asrMadhab"
        static let highLatitudeRule = "highLatitudeRule"
        static let jumuah = "jumuah"
        static let khutbah = "khutbah"
        static let iqamah = "iqamah"
        static let adminUIDs = "adminUIDs"
        static let verified = "verified"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"
    }

    /// The editable details of `masjid`.
    static func data(for masjid: Masjid) -> [String: Any] {
        [
            Key.name: masjid.name,
            Key.address: masjid.address,
            Key.latitude: masjid.coordinates.latitude,
            Key.longitude: masjid.coordinates.longitude,
            Key.geohash: Geohash.encode(masjid.coordinates),
            Key.timeZone: masjid.timeZoneIdentifier,
            Key.calculationMethod: masjid.calculation.method.rawValue,
            Key.asrMadhab: masjid.calculation.asrMadhab.rawValue,
            Key.highLatitudeRule: masjid.calculation.highLatitudeRule.rawValue,
            Key.jumuah: masjid.jumuah.map { slot -> [String: String] in
                var entry = [Key.khutbah: slot.khutbah.description]
                if let iqamah = slot.iqamah {
                    entry[Key.iqamah] = iqamah.description
                }
                return entry
            },
        ]
    }

    static func masjid(id: String, data: [String: Any]) throws -> Masjid {
        guard let name = data[Key.name] as? String,
              let address = data[Key.address] as? String,
              let latitude = data[Key.latitude] as? Double,
              let longitude = data[Key.longitude] as? Double,
              let timeZone = data[Key.timeZone] as? String
        else { throw RepositoryError.invalidData("masjid \(id) is missing required fields") }

        let coordinates = Coordinates(latitude: latitude, longitude: longitude)
        guard coordinates.isValid else { throw RepositoryError.invalidData("masjid \(id) has invalid coordinates") }

        // Unknown or missing settings fall back to defaults rather than hiding the masjid.
        let method = (data[Key.calculationMethod] as? String).flatMap(CalculationMethod.init(rawValue:)) ?? .isna
        let madhab = (data[Key.asrMadhab] as? String).flatMap(AsrMadhab.init(rawValue:)) ?? .standard
        let rule = (data[Key.highLatitudeRule] as? String).flatMap(HighLatitudeRule.init(rawValue:)) ?? .middleOfNight

        let jumuahEntries = data[Key.jumuah] as? [[String: Any]] ?? []
        let jumuah = try jumuahEntries.map { entry -> JumuahSlot in
            guard let khutbah = (entry[Key.khutbah] as? String).flatMap({ WallClockTime($0) }) else {
                throw RepositoryError.invalidData("masjid \(id) has an invalid Jumu'ah time")
            }
            return JumuahSlot(khutbah: khutbah, iqamah: (entry[Key.iqamah] as? String).flatMap { WallClockTime($0) })
        }

        return Masjid(
            id: id,
            name: name,
            address: address,
            coordinates: coordinates,
            timeZoneIdentifier: timeZone,
            calculation: CalculationParameters(method: method, asrMadhab: madhab, highLatitudeRule: rule),
            jumuah: jumuah,
            isVerified: data[Key.verified] as? Bool ?? false
        )
    }
}

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

    static func times(from data: [String: Any]) throws -> DailyPrayerTimes {
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
            source: source
        )
    }
}
