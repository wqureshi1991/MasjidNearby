import Foundation
@testable import MasjidNearby

/// Shared by the prayer alert tests. Calculated times are always Fixtures.times: Fajr 05:53,
/// Dhuhr 12:57, Asr 16:17, Maghrib 18:49, Isha 20:01, in Los Angeles.
enum AlertFixtures {
    static let calculator = MockPrayerTimeCalculator(result: .success(Fixtures.times(on: "2026-10-21")))
    static let enabled = PrayerAlertSettings(isEnabled: true)
    /// From noon on 21 October: Dhuhr, Asr, Maghrib and Isha today, then 5 a day for 6 days.
    static let alertsFromNoon = 34

    static func instant(_ time: String, on day: String) -> Date {
        Fixtures.time(time).instant(on: Fixtures.day(day), in: TimeZone(identifier: "America/Los_Angeles") ?? .gmt)
    }

    static func store(with masjids: [Masjid]) async throws -> InMemoryOfflineStore {
        let store = InMemoryOfflineStore()
        for masjid in masjids {
            try await store.saveFavorite(masjid, at: OfflineFixtures.noon)
        }
        return store
    }
}
