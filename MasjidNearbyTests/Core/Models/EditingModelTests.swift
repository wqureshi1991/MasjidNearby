import Foundation
import Testing
@testable import MasjidNearby

struct EditingModelTests {
    @Test func hiddenIqamahDoesNotAffectEquality() {
        var a = EditablePrayer(PrayerTime(adhan: Fixtures.time("05:53")))
        var b = a
        b.iqamah = Fixtures.time("06:30")
        #expect(a == b)

        a.hasIqamah = true
        #expect(a != b)
        #expect(a.prayerTime.iqamah == Fixtures.time("06:08"))
    }

    @Test func editableDayProducesManualTimesForAnyDay() {
        let editable = EditableDay(Fixtures.times(on: "2026-10-21", fajrIqamah: "06:15"))
        let moved = editable.dailyTimes(on: Fixtures.day("2026-10-25"))
        #expect(moved.day.key == "2026-10-25")
        #expect(moved.source == .manual)
        #expect(moved.fajr.iqamah == Fixtures.time("06:15"))
    }

    @Test func wallClockTimeFromDateUsesTheTimeZone() throws {
        let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
        // 2026-10-21 20:30 UTC is 13:30 in California (PDT).
        let instant = Fixtures.day("2026-10-21").startOfDayUTC.addingTimeInterval(20.5 * 3_600)
        #expect(WallClockTime(date: instant, in: losAngeles) == Fixtures.time("13:30"))
        #expect(WallClockTime(date: Fixtures.time("13:30").pickerDate(in: losAngeles), in: losAngeles) == Fixtures.time("13:30"))
    }

    @Test func minutesUntilWrapsPastMidnight() {
        #expect(Fixtures.time("23:50").minutes(until: Fixtures.time("00:10")) == 20)
        #expect(Fixtures.time("05:00").minutes(until: Fixtures.time("05:15")) == 15)
    }
}
