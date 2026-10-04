import Foundation
import Testing
@testable import MasjidNearby

struct WallClockTimeTests {
    @Test func parsesStrictTwentyFourHourFormat() throws {
        let time = try #require(WallClockTime("05:07"))
        #expect(time.hour == 5)
        #expect(time.minute == 7)
        #expect(time.description == "05:07")
        #expect(time.minutesSinceMidnight == 307)
    }

    @Test func rejectsMalformedStrings() {
        for string in ["", "5:07", "05:7", "0507", "24:00", "12:60", "ab:cd", "12:30:00", " 12:30", "-1:30"] {
            #expect(WallClockTime(string) == nil, "\(string) should not parse")
        }
    }

    @Test func rejectsOutOfRangeComponents() {
        #expect(WallClockTime(hour: 24, minute: 0) == nil)
        #expect(WallClockTime(hour: -1, minute: 0) == nil)
        #expect(WallClockTime(hour: 0, minute: 60) == nil)
        #expect(WallClockTime(hour: 23, minute: 59) != nil)
    }

    @Test func wrapsMinutesOntoTheClock() {
        #expect(WallClockTime(wrappingMinutesSinceMidnight: 1_445).description == "00:05")
        #expect(WallClockTime(wrappingMinutesSinceMidnight: -5).description == "23:55")
        #expect(WallClockTime(wrappingMinutesSinceMidnight: 0).description == "00:00")
    }

    @Test func ordersByTimeOfDay() throws {
        let early = try #require(WallClockTime("05:59"))
        let late = try #require(WallClockTime("06:00"))
        #expect(early < late)
    }

    @Test func codesAsAString() throws {
        let time = try #require(WallClockTime("18:45"))
        let data = try JSONEncoder().encode([time])
        #expect(String(decoding: data, as: UTF8.self) == "[\"18:45\"]")
        #expect(try JSONDecoder().decode([WallClockTime].self, from: data) == [time])
    }

    @Test func decodingMalformedTimeThrows() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([WallClockTime].self, from: Data("[\"25:00\"]".utf8))
        }
    }

    @Test func convertsToAnInstantInTheMasjidTimeZone() throws {
        let time = try #require(WallClockTime("13:30"))
        let day = try #require(CalendarDay(key: "2026-07-01"))
        let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let date = try #require(time.date(on: day, in: losAngeles))
        // 13:30 PDT is 20:30 UTC.
        #expect(date == day.startOfDayUTC.addingTimeInterval(20.5 * 3_600))
    }

    @Test func timeInsideSpringForwardGapHasNoInstant() throws {
        let time = try #require(WallClockTime("02:30"))
        let day = try #require(CalendarDay(key: "2026-03-08"))
        let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
        #expect(time.date(on: day, in: losAngeles) == nil)
    }
}

struct CalendarDayTests {
    @Test func parsesAndFormatsKey() throws {
        let day = try #require(CalendarDay(key: "2026-10-02"))
        #expect(day.year == 2026)
        #expect(day.month == 10)
        #expect(day.day == 2)
        #expect(day.key == "2026-10-02")
    }

    @Test func rejectsInvalidDates() {
        for key in ["2026-02-29", "2026-13-01", "2026-00-10", "2026-04-31", "2026-1-01", "20261002", "abcd-ef-gh", ""] {
            #expect(CalendarDay(key: key) == nil, "\(key) should not parse")
        }
        #expect(CalendarDay(key: "2028-02-29") != nil)
    }

    @Test func julianDayNumberRoundTrips() throws {
        let epoch = try #require(CalendarDay(year: 1970, month: 1, day: 1))
        #expect(epoch.julianDayNumber == 2_440_588)
        #expect(CalendarDay(julianDayNumber: 2_451_545) == CalendarDay(year: 2000, month: 1, day: 1))

        let start = try #require(CalendarDay(year: 2024, month: 1, day: 1))
        for offset in 0..<1_500 {
            let day = start.adding(days: offset)
            #expect(CalendarDay(julianDayNumber: day.julianDayNumber) == day)
            #expect(CalendarDay(key: day.key) == day)
        }
    }

    @Test func addsDaysAcrossMonthAndYearBoundaries() throws {
        let newYearsEve = try #require(CalendarDay(key: "2026-12-31"))
        #expect(newYearsEve.adding(days: 1).key == "2027-01-01")

        let leapDayEve = try #require(CalendarDay(key: "2028-02-28"))
        #expect(leapDayEve.adding(days: 1).key == "2028-02-29")
        #expect(leapDayEve.adding(days: 2).key == "2028-03-01")
        #expect(leapDayEve.adding(days: -28).key == "2028-01-31")
    }

    @Test func ordersChronologically() throws {
        let earlier = try #require(CalendarDay(key: "2026-09-30"))
        let later = try #require(CalendarDay(key: "2026-10-01"))
        #expect(earlier < later)
    }

    @Test func dayDependsOnTimeZone() throws {
        // 2026-10-02 03:00 UTC is still 1 October in California.
        let utcDay = try #require(CalendarDay(key: "2026-10-02"))
        let instant = utcDay.startOfDayUTC.addingTimeInterval(3 * 3_600)
        let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let karachi = try #require(TimeZone(identifier: "Asia/Karachi"))
        #expect(CalendarDay(date: instant, in: losAngeles).key == "2026-10-01")
        #expect(CalendarDay(date: instant, in: karachi).key == "2026-10-02")
    }

    @Test func codesAsAKeyString() throws {
        let day = try #require(CalendarDay(key: "2026-10-02"))
        let data = try JSONEncoder().encode([day])
        #expect(String(decoding: data, as: UTF8.self) == "[\"2026-10-02\"]")
        #expect(try JSONDecoder().decode([CalendarDay].self, from: data) == [day])
    }

    @Test func decodingInvalidDayThrows() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([CalendarDay].self, from: Data("[\"2026-02-30\"]".utf8))
        }
    }
}

struct DailyPrayerTimesTests {
    @Test func decodesAScheduleDocument() throws {
        let json = """
        {
          "day": "2026-10-02",
          "fajr": { "adhan": "05:53", "iqamah": "06:15" },
          "sunrise": "07:04",
          "dhuhr": { "adhan": "12:57", "iqamah": "13:30" },
          "asr": { "adhan": "16:17", "iqamah": "16:45" },
          "maghrib": { "adhan": "18:49" },
          "isha": { "adhan": "20:01", "iqamah": "20:30" },
          "source": "manual"
        }
        """
        let times = try JSONDecoder().decode(DailyPrayerTimes.self, from: Data(json.utf8))

        #expect(times.day.key == "2026-10-02")
        #expect(times.source == .manual)
        #expect(times[.fajr].iqamah?.description == "06:15")
        #expect(times[.maghrib].adhan.description == "18:49")
        #expect(times[.maghrib].iqamah == nil)
        #expect(try JSONDecoder().decode(DailyPrayerTimes.self, from: JSONEncoder().encode(times)) == times)
    }

    @Test func unknownSourceFailsToDecode() {
        let json = """
        { "day": "2026-10-02", "fajr": { "adhan": "05:53" }, "sunrise": "07:04", "dhuhr": { "adhan": "12:57" },
          "asr": { "adhan": "16:17" }, "maghrib": { "adhan": "18:49" }, "isha": { "adhan": "20:01" }, "source": "guess" }
        """
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(DailyPrayerTimes.self, from: Data(json.utf8))
        }
    }

    @Test func calculationMethodRawValuesAreStable() {
        #expect(CalculationMethod.isna.rawValue == "isna")
        #expect(CalculationMethod.muslimWorldLeague.rawValue == "mwl")
        #expect(CalculationMethod.ummAlQura.rawValue == "ummAlQura")
        #expect(CalculationMethod.egyptian.rawValue == "egyptian")
        #expect(CalculationMethod.karachi.rawValue == "karachi")
        #expect(AsrMadhab.standard.shadowFactor == 1)
        #expect(AsrMadhab.hanafi.shadowFactor == 2)
    }
}
