import Foundation
import Testing
@testable import MasjidNearby

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
