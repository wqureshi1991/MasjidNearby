import Foundation
import Testing
@testable import MasjidNearby

struct GeohashSearchTests {
    @Test func boundsMatchTheReferenceCell() throws {
        // Wikipedia's worked example: ezs42 spans 42.583–42.627 N, 5.625–5.581 W.
        let cell = try #require(Geohash.bounds(of: "ezs42"))
        #expect(abs(cell.latitude.lowerBound - 42.5830078125) < 1e-9)
        #expect(abs(cell.latitude.upperBound - 42.626953125) < 1e-9)
        #expect(abs(cell.longitude.lowerBound - -5.625) < 1e-9)
        #expect(abs(cell.longitude.upperBound - -5.5810546875) < 1e-9)
        #expect(Geohash.bounds(of: "ab!") == nil)
    }

    @Test func neighborsMatchTheReferenceSet() {
        // The standard example used by geohash libraries.
        #expect(Set(Geohash.neighbors(of: "dqcjq"))
                == ["dqcjj", "dqcjn", "dqcjp", "dqcjm", "dqcjr", "dqcjt", "dqcjw", "dqcjx"])
    }

    @Test func neighborsWrapAcrossTheAntimeridian() {
        let east = Geohash.encode(Coordinates(latitude: 0.5, longitude: 179.9), precision: 4)
        let west = Geohash.encode(Coordinates(latitude: 0.5, longitude: -179.9), precision: 4)
        #expect(Geohash.neighbors(of: east).contains(west))
    }

    @Test func precisionShrinksAsTheRadiusGrows() {
        #expect(Geohash.precision(forRadiusMeters: 5_000, latitude: 37.3) == 4)
        #expect(Geohash.precision(forRadiusMeters: 25_000, latitude: 37.3) == 3)
        #expect(Geohash.precision(forRadiusMeters: 500, latitude: 37.3) >= 5)
    }

    @Test func coveringPrefixesIncludeEveryPointInTheRadius() {
        let center = Fixtures.sanJose
        let radius = 25_000.0
        let prefixes = Geohash.coveringPrefixes(around: center, radiusMeters: radius)
        let precision = prefixes[0].count
        let metersPerDegree = 111_320.0

        for bearing in stride(from: 0.0, to: 360.0, by: 15.0) {
            let radians = bearing * .pi / 180
            let point = Coordinates(
                latitude: center.latitude + cos(radians) * radius * 0.99 / metersPerDegree,
                longitude: center.longitude + sin(radians) * radius * 0.99
                    / (metersPerDegree * cos(center.latitude * .pi / 180))
            )
            #expect(prefixes.contains(Geohash.encode(point, precision: precision)), "bearing \(bearing)")
        }
    }

    @Test func distanceMatchesKnownValue() {
        let sanFrancisco = Coordinates(latitude: 37.7749, longitude: -122.4194)
        #expect(abs(Fixtures.sanJose.distance(to: sanFrancisco) - 67_570) < 500)
        #expect(Fixtures.sanJose.distance(to: Fixtures.sanJose) == 0)
    }
}

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

struct DemoDataTests {
    @Test func seedsVerifiedSampleMasjidsWithOnePublishedSchedule() async throws {
        let now = Fixtures.day("2026-10-21").startOfDayUTC.addingTimeInterval(19 * 3_600)
        let repository = DemoData.repository(now: now)

        let masjids = try await repository.verifiedMasjids(near: Fixtures.sanJose, radiusMeters: 25_000)
        #expect(masjids.count == 3)
        #expect(masjids.allSatisfy { $0.name.hasPrefix("Sample") })

        let today = Fixtures.day("2026-10-21")
        let published = try await repository.schedule(masjidID: "sample-downtown", from: today, through: today)
        #expect(published.first?.source == .manual)
        #expect(published.first?.fajr.iqamah != nil)
        #expect(try await repository.schedule(masjidID: "sample-milpitas", from: today, through: today).isEmpty)
    }
}
