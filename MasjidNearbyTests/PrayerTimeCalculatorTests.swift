import Foundation
import Testing
@testable import MasjidNearby

struct PrayerTimeCalculatorTests {
    private let calculator = AstronomicalPrayerTimeCalculator()

    // MARK: - Reference times

    /// Expected values come from an independent calculation: root-finding on the sun's true altitude
    /// with the PyEphem (VSOP87) ephemeris, rounded the same way as the calculator.
    private struct Reference: Sendable {
        let place: String
        let coordinates: Coordinates
        let timeZoneID: String
        let parameters: CalculationParameters
        let day: String
        /// Fajr, sunrise, Dhuhr, Asr, Maghrib, Isha.
        let expected: [String]
    }

    private static let labels = ["fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"]

    private static let sanJose = Coordinates(latitude: 37.3382, longitude: -121.8863)
    private static let makkah = Coordinates(latitude: 21.4225, longitude: 39.8262)
    private static let london = Coordinates(latitude: 51.5074, longitude: -0.1278)
    private static let karachi = Coordinates(latitude: 24.8607, longitude: 67.0011)
    private static let tromso = Coordinates(latitude: 69.6492, longitude: 18.9553)

    private static let isna = CalculationParameters(method: .isna)
    private static let mwl = CalculationParameters(method: .muslimWorldLeague)
    private static let ummAlQura = CalculationParameters(method: .ummAlQura)
    private static let karachiHanafi = CalculationParameters(method: .karachi, asrMadhab: .hanafi)

    private static let references: [Reference] = [
        Reference(place: "San Jose", coordinates: sanJose, timeZoneID: "America/Los_Angeles", parameters: isna,
                  day: "2026-01-15", expected: ["06:05", "07:20", "12:18", "14:55", "17:14", "18:31"]),
        Reference(place: "San Jose", coordinates: sanJose, timeZoneID: "America/Los_Angeles", parameters: isna,
                  day: "2026-06-21", expected: ["04:17", "05:47", "13:10", "17:03", "20:32", "22:03"]),
        Reference(place: "San Jose", coordinates: sanJose, timeZoneID: "America/Los_Angeles", parameters: isna,
                  day: "2026-10-02", expected: ["05:53", "07:04", "12:57", "16:17", "18:49", "20:01"]),
        // Day before and day of the spring DST change.
        Reference(place: "San Jose", coordinates: sanJose, timeZoneID: "America/Los_Angeles", parameters: isna,
                  day: "2026-03-07", expected: ["05:19", "06:29", "12:19", "15:36", "18:08", "19:19"]),
        Reference(place: "San Jose", coordinates: sanJose, timeZoneID: "America/Los_Angeles", parameters: isna,
                  day: "2026-03-08", expected: ["06:18", "07:28", "13:19", "16:37", "19:09", "20:20"]),
        // Day before and day of the autumn DST change.
        Reference(place: "San Jose", coordinates: sanJose, timeZoneID: "America/Los_Angeles", parameters: isna,
                  day: "2026-10-31", expected: ["06:19", "07:31", "12:51", "15:48", "18:11", "19:24"]),
        Reference(place: "San Jose", coordinates: sanJose, timeZoneID: "America/Los_Angeles", parameters: isna,
                  day: "2026-11-01", expected: ["05:20", "06:32", "11:51", "14:47", "17:10", "18:23"]),
        Reference(place: "Makkah", coordinates: makkah, timeZoneID: "Asia/Riyadh", parameters: ummAlQura,
                  day: "2026-03-20", expected: ["05:09", "06:24", "12:29", "15:53", "18:32", "20:02"]),
        Reference(place: "Makkah", coordinates: makkah, timeZoneID: "Asia/Riyadh", parameters: ummAlQura,
                  day: "2026-12-21", expected: ["05:33", "06:53", "12:19", "15:23", "17:44", "19:14"]),
        Reference(place: "London", coordinates: london, timeZoneID: "Europe/London", parameters: mwl,
                  day: "2026-01-15", expected: ["06:00", "07:59", "12:11", "14:02", "16:21", "18:15"]),
        Reference(place: "London", coordinates: london, timeZoneID: "Europe/London", parameters: mwl,
                  day: "2026-04-10", expected: ["04:12", "06:15", "13:02", "16:45", "19:49", "21:46"]),
        // UK clocks go back on this day.
        Reference(place: "London", coordinates: london, timeZoneID: "Europe/London", parameters: mwl,
                  day: "2026-10-25", expected: ["04:50", "06:41", "11:45", "14:17", "16:47", "18:33"]),
        Reference(place: "Karachi", coordinates: karachi, timeZoneID: "Asia/Karachi", parameters: karachiHanafi,
                  day: "2026-02-10", expected: ["05:53", "07:09", "12:47", "16:47", "18:23", "19:41"]),
        Reference(place: "Karachi", coordinates: karachi, timeZoneID: "Asia/Karachi", parameters: karachiHanafi,
                  day: "2026-08-15", expected: ["04:46", "06:06", "12:37", "17:13", "19:07", "20:28"]),
    ]

    @Test func matchesEphemerisReferenceWithinOneMinute() throws {
        for reference in Self.references {
            let day = try #require(CalendarDay(key: reference.day))
            let timeZone = try #require(TimeZone(identifier: reference.timeZoneID))
            let times = try calculator.times(on: day, at: reference.coordinates, in: timeZone,
                                             parameters: reference.parameters)
            let actual = [times.fajr.adhan, times.sunrise, times.dhuhr.adhan,
                          times.asr.adhan, times.maghrib.adhan, times.isha.adhan]

            for (index, expectedString) in reference.expected.enumerated() {
                let expected = try #require(WallClockTime(expectedString))
                #expect(
                    minutesApart(actual[index], expected) <= 1,
                    "\(reference.place) \(reference.day) \(Self.labels[index]): got \(actual[index]), want \(expected)"
                )
            }
        }
    }

    @Test func calculatedTimesAreMarkedCalculatedWithNoIqamah() throws {
        let times = try sanJoseTimes(on: "2026-10-02")
        #expect(times.source == .calculated)
        for prayer in Prayer.allCases {
            #expect(times[prayer].iqamah == nil)
        }
    }

    // MARK: - Daylight saving

    @Test func springForwardShiftsWallClockByAnHour() throws {
        let before = try sanJoseTimes(on: "2026-03-07")
        let after = try sanJoseTimes(on: "2026-03-08")
        let shift = after.dhuhr.adhan.minutesSinceMidnight - before.dhuhr.adhan.minutesSinceMidnight
        #expect((59...61).contains(shift))
    }

    @Test func fallBackShiftsWallClockByAnHour() throws {
        let before = try sanJoseTimes(on: "2026-10-31")
        let after = try sanJoseTimes(on: "2026-11-01")
        let shift = before.dhuhr.adhan.minutesSinceMidnight - after.dhuhr.adhan.minutesSinceMidnight
        #expect((59...61).contains(shift))
    }

    // MARK: - Methods and madhab

    @Test func ummAlQuraIshaIsNinetyMinutesAfterMaghrib() throws {
        let day = try #require(CalendarDay(key: "2026-03-20"))
        let timeZone = try #require(TimeZone(identifier: "Asia/Riyadh"))
        let times = try calculator.times(on: day, at: Self.makkah, in: timeZone, parameters: Self.ummAlQura)
        #expect(times.isha.adhan.minutesSinceMidnight - times.maghrib.adhan.minutesSinceMidnight == 90)
    }

    @Test func hanafiAsrIsLaterThanStandard() throws {
        let day = try #require(CalendarDay(key: "2026-02-10"))
        let timeZone = try #require(TimeZone(identifier: "Asia/Karachi"))
        let standard = try calculator.times(on: day, at: Self.karachi, in: timeZone,
                                            parameters: CalculationParameters(method: .karachi, asrMadhab: .standard))
        let hanafi = try calculator.times(on: day, at: Self.karachi, in: timeZone, parameters: Self.karachiHanafi)
        #expect(hanafi.asr.adhan > standard.asr.adhan)
        #expect(hanafi.dhuhr == standard.dhuhr)
    }

    @Test func timesAreInOrderThroughTheDay() throws {
        let times = try sanJoseTimes(on: "2026-06-21")
        let ordered = [times.fajr.adhan, times.sunrise, times.dhuhr.adhan,
                       times.asr.adhan, times.maghrib.adhan, times.isha.adhan]
        #expect(ordered == ordered.sorted())
    }

    // MARK: - High latitudes

    /// London at midsummer: the sun never gets 17 or 18 degrees below the horizon.
    @Test func noHighLatitudeRuleFailsWhenTwilightNeverEnds() throws {
        let day = try #require(CalendarDay(key: "2026-06-21"))
        let timeZone = try #require(TimeZone(identifier: "Europe/London"))
        let parameters = CalculationParameters(method: .muslimWorldLeague, highLatitudeRule: .none)

        #expect(throws: PrayerCalculationError.twilightDoesNotOccur) {
            try calculator.times(on: day, at: Self.london, in: timeZone, parameters: parameters)
        }
    }

    @Test func middleOfNightPutsFajrAndIshaAtSolarMidnight() throws {
        let times = try londonMidsummerTimes(rule: .middleOfNight)
        #expect(times.fajr.adhan == times.isha.adhan)
        #expect(times.fajr.adhan < times.sunrise)
    }

    @Test func seventhOfNightIsCloserToSunriseThanMiddleOfNight() throws {
        let middle = try londonMidsummerTimes(rule: .middleOfNight)
        let seventh = try londonMidsummerTimes(rule: .seventhOfNight)
        let angle = try londonMidsummerTimes(rule: .twilightAngle)

        #expect(seventh.fajr.adhan > angle.fajr.adhan)
        #expect(angle.fajr.adhan > middle.fajr.adhan)
        #expect(seventh.fajr.adhan < seventh.sunrise)
        #expect(seventh.sunrise == middle.sunrise)
    }

    // MARK: - Errors

    @Test func polarDayThrows() throws {
        let day = try #require(CalendarDay(key: "2026-06-21"))
        let timeZone = try #require(TimeZone(identifier: "Europe/Oslo"))

        #expect(throws: PrayerCalculationError.sunDoesNotRiseOrSet) {
            try calculator.times(on: day, at: Self.tromso, in: timeZone, parameters: Self.mwl)
        }
    }

    @Test func invalidCoordinatesThrow() throws {
        let day = try #require(CalendarDay(key: "2026-06-21"))
        let timeZone = try #require(TimeZone(identifier: "UTC"))
        let nowhere = Coordinates(latitude: 91, longitude: 0)

        #expect(throws: PrayerCalculationError.invalidCoordinates) {
            try calculator.times(on: day, at: nowhere, in: timeZone, parameters: Self.isna)
        }
    }

    // MARK: - Helpers

    private func sanJoseTimes(on key: String) throws -> DailyPrayerTimes {
        let day = try #require(CalendarDay(key: key))
        let timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        return try calculator.times(on: day, at: Self.sanJose, in: timeZone, parameters: Self.isna)
    }

    private func londonMidsummerTimes(rule: HighLatitudeRule) throws -> DailyPrayerTimes {
        let day = try #require(CalendarDay(key: "2026-06-21"))
        let timeZone = try #require(TimeZone(identifier: "Europe/London"))
        let parameters = CalculationParameters(method: .muslimWorldLeague, highLatitudeRule: rule)
        return try calculator.times(on: day, at: Self.london, in: timeZone, parameters: parameters)
    }

    private func minutesApart(_ lhs: WallClockTime, _ rhs: WallClockTime) -> Int {
        let difference = abs(lhs.minutesSinceMidnight - rhs.minutesSinceMidnight)
        return min(difference, 1_440 - difference)
    }
}
