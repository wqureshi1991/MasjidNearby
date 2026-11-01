import Foundation
import Testing
@testable import MasjidNearby

struct PrayerTimeResolverTests {
    @Test func prefersTheMasjidsPublishedSchedule() throws {
        let day = try #require(CalendarDay(key: "2026-10-02"))
        let published = try makeTimes(day: day, fajr: "06:10", source: .manual)
        let calculated = try makeTimes(day: day, fajr: "05:53", source: .calculated)
        let resolver = PrayerTimeResolver(calculator: MockPrayerTimeCalculator(result: .success(calculated)))

        let resolved = try resolver.times(for: makeMasjid(), on: day, published: published)

        #expect(resolved == published)
        #expect(resolved.source == .manual)
    }

    @Test func fallsBackToCalculatedTimesWhenNothingIsPublished() throws {
        let day = try #require(CalendarDay(key: "2026-10-02"))
        let calculated = try makeTimes(day: day, fajr: "05:53", source: .calculated)
        let resolver = PrayerTimeResolver(calculator: MockPrayerTimeCalculator(result: .success(calculated)))

        let resolved = try resolver.times(for: makeMasjid(), on: day, published: nil)

        #expect(resolved == calculated)
        #expect(resolved.source == .calculated)
    }

    @Test func ignoresAPublishedScheduleForADifferentDay() throws {
        let day = try #require(CalendarDay(key: "2026-10-02"))
        let stale = try makeTimes(day: day.adding(days: -1), fajr: "06:10", source: .manual)
        let calculated = try makeTimes(day: day, fajr: "05:53", source: .calculated)
        let resolver = PrayerTimeResolver(calculator: MockPrayerTimeCalculator(result: .success(calculated)))

        let resolved = try resolver.times(for: makeMasjid(), on: day, published: stale)

        #expect(resolved == calculated)
    }

    @Test func propagatesCalculationErrors() throws {
        let day = try #require(CalendarDay(key: "2026-06-21"))
        let resolver = PrayerTimeResolver(calculator: MockPrayerTimeCalculator(result: .failure(.sunDoesNotRiseOrSet)))

        #expect(throws: PrayerCalculationError.sunDoesNotRiseOrSet) {
            try resolver.times(for: makeMasjid(), on: day, published: nil)
        }
    }

    @Test func unknownTimeZoneThrows() throws {
        let day = try #require(CalendarDay(key: "2026-10-02"))
        let calculated = try makeTimes(day: day, fajr: "05:53", source: .calculated)
        let resolver = PrayerTimeResolver(calculator: MockPrayerTimeCalculator(result: .success(calculated)))

        #expect(throws: PrayerCalculationError.invalidTimeZone) {
            try resolver.times(for: makeMasjid(timeZoneIdentifier: "Nowhere/Invalid"), on: day, published: nil)
        }
    }

    /// End to end with the real calculator: a masjid with no schedule still gets times.
    @Test func realCalculatorProducesTimesForAMasjidWithNoSchedule() throws {
        let day = try #require(CalendarDay(key: "2026-10-02"))
        let resolver = PrayerTimeResolver(calculator: AstronomicalPrayerTimeCalculator())

        let resolved = try resolver.times(for: makeMasjid(), on: day, published: nil)

        #expect(resolved.source == .calculated)
        #expect(resolved.day == day)
        #expect(resolved.fajr.adhan < resolved.sunrise)
    }

    // MARK: - Helpers

    private func makeMasjid(timeZoneIdentifier: String = "America/Los_Angeles") -> Masjid {
        Masjid(
            id: "masjid-1",
            name: "Test Masjid",
            address: "1 Main St, San Jose, CA",
            coordinates: Coordinates(latitude: 37.3382, longitude: -121.8863),
            timeZoneIdentifier: timeZoneIdentifier,
            calculation: CalculationParameters(method: .isna),
            jumuah: [],
            isVerified: true
        )
    }

    private func makeTimes(day: CalendarDay, fajr: String, source: PrayerTimeSource) throws -> DailyPrayerTimes {
        DailyPrayerTimes(
            day: day,
            fajr: PrayerTime(adhan: try #require(WallClockTime(fajr))),
            sunrise: try #require(WallClockTime("07:04")),
            dhuhr: PrayerTime(adhan: try #require(WallClockTime("12:57"))),
            asr: PrayerTime(adhan: try #require(WallClockTime("16:17"))),
            maghrib: PrayerTime(adhan: try #require(WallClockTime("18:49"))),
            isha: PrayerTime(adhan: try #require(WallClockTime("20:01"))),
            source: source
        )
    }
}
