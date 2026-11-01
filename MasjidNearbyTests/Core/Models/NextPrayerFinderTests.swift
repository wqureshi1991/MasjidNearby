import Foundation
import Testing
@testable import MasjidNearby

struct NextPrayerFinderTests {
    private let losAngeles = TimeZone(identifier: "America/Los_Angeles") ?? .current

    /// `hour`:`minute` Pacific Daylight Time on 2026-10-21, as an instant.
    private func pdt(_ hour: Int, _ minute: Int, dayOffset: Int = 0) -> Date {
        Fixtures.day("2026-10-21").startOfDayUTC
            .addingTimeInterval(Double(dayOffset * 86_400 + (hour + 7) * 3_600 + minute * 60))
    }

    @Test func findsTheNextPrayerToday() {
        let today = Fixtures.times(on: "2026-10-21")
        let next = NextPrayerFinder.next(after: pdt(12, 0), today: today, tomorrow: nil, in: losAngeles)

        #expect(next?.prayer == .dhuhr)
        #expect(next?.adhan == pdt(12, 57))
        #expect(next?.isTomorrow == false)
    }

    @Test func iqamahIsOffsetFromItsAdhan() {
        let today = Fixtures.times(on: "2026-10-21", fajrIqamah: "06:15")
        let next = NextPrayerFinder.next(after: pdt(4, 0), today: today, tomorrow: nil, in: losAngeles)

        #expect(next?.prayer == .fajr)
        #expect(next?.iqamah == pdt(6, 15))
    }

    @Test func afterIshaItIsTomorrowsFajr() {
        let today = Fixtures.times(on: "2026-10-21")
        let tomorrow = Fixtures.times(on: "2026-10-22", fajr: "05:54")
        let next = NextPrayerFinder.next(after: pdt(21, 0), today: today, tomorrow: tomorrow, in: losAngeles)

        #expect(next?.prayer == .fajr)
        #expect(next?.adhan == pdt(5, 54, dayOffset: 1))
        #expect(next?.isTomorrow == true)
    }

    @Test func afterIshaWithoutTomorrowIsNil() {
        let today = Fixtures.times(on: "2026-10-21")
        #expect(NextPrayerFinder.next(after: pdt(21, 0), today: today, tomorrow: nil, in: losAngeles) == nil)
    }

    @Test func ishaAfterMidnightFallsOnTheNextDay() {
        let today = DailyPrayerTimes(
            day: Fixtures.day("2026-10-21"),
            fajr: PrayerTime(adhan: Fixtures.time("05:53")),
            sunrise: Fixtures.time("07:04"),
            dhuhr: PrayerTime(adhan: Fixtures.time("12:57")),
            asr: PrayerTime(adhan: Fixtures.time("16:17")),
            maghrib: PrayerTime(adhan: Fixtures.time("21:22")),
            isha: PrayerTime(adhan: Fixtures.time("00:40")),
            source: .manual
        )
        let next = NextPrayerFinder.next(after: pdt(22, 0), today: today, tomorrow: nil, in: losAngeles)

        #expect(next?.prayer == .isha)
        #expect(next?.adhan == pdt(0, 40, dayOffset: 1))
    }

    @Test func usesTheOffsetInForceOnADSTChangeDay() {
        // Clocks go back on 2026-11-01: 05:20 that morning is PST, UTC-8.
        let day = Fixtures.times(on: "2026-11-01", fajr: "05:20")
        let fajr = NextPrayerFinder.instants(of: day, in: losAngeles).first

        #expect(fajr?.adhan == Fixtures.day("2026-11-01").startOfDayUTC.addingTimeInterval(13 * 3_600 + 20 * 60))
    }
}
