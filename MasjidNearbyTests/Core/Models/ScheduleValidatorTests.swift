import Foundation
import Testing
@testable import MasjidNearby

struct ScheduleValidatorTests {
    @Test func calculatedDayHasNoIssues() {
        #expect(ScheduleValidator.issues(in: Fixtures.times(on: "2026-10-21")).isEmpty)
    }

    @Test func flagsPrayersOutOfOrder() {
        let times = Fixtures.times(on: "2026-10-21", dhuhr: "06:30")
        #expect(ScheduleValidator.issues(in: times).contains(.outOfOrder(earlier: "Sunrise", later: "Dhuhr")))
    }

    @Test func flagsIqamahBeforeAdhanAndTooLate() {
        let before = Fixtures.times(on: "2026-10-21", fajr: "05:53", fajrIqamah: "05:40")
        #expect(ScheduleValidator.issues(in: before) == [.iqamahBeforeAdhan(.fajr)])

        let late = Fixtures.times(on: "2026-10-21", fajr: "05:00", fajrIqamah: "07:30")
        #expect(ScheduleValidator.issues(in: late).contains(.iqamahTooLate(.fajr)))
    }

    @Test func allowsIshaAfterMidnight() {
        let times = DailyPrayerTimes(
            day: Fixtures.day("2026-06-21"),
            fajr: PrayerTime(adhan: Fixtures.time("01:30")),
            sunrise: Fixtures.time("04:43"),
            dhuhr: PrayerTime(adhan: Fixtures.time("13:03")),
            asr: PrayerTime(adhan: Fixtures.time("17:26")),
            maghrib: PrayerTime(adhan: Fixtures.time("21:22")),
            isha: PrayerTime(adhan: Fixtures.time("00:40"), iqamah: Fixtures.time("00:50")),
            source: .manual
        )
        #expect(ScheduleValidator.issues(in: times).isEmpty)
    }
}
