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
