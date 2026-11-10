import Foundation
import Testing
@testable import MasjidNearby

struct BackgroundRefreshTests {
    @Test func refreshesFavoritesThenAlertsAndAsksForTheNextRun() async throws {
        let store = try await AlertFixtures.store(with: [Fixtures.masjid()])
        let repository = MockMasjidRepository(published: [
            "m1": [Fixtures.times(on: "2026-10-21", dhuhr: "13:30", source: .manual)],
        ])
        let scheduler = MockNotificationScheduler(status: .authorized)
        let requested = Recorder<Date>()
        let refresh = BackgroundRefresh(
            favorites: FavoritesSync(repository: repository, store: store),
            alerts: PrayerAlertSync(store: store, settings: InMemoryPrayerAlertSettingsStore(AlertFixtures.enabled),
                                    scheduler: scheduler, calculator: AlertFixtures.calculator),
            scheduleNext: { requested.record($0) }
        )

        await refresh.run(now: OfflineFixtures.noon)

        // The newly downloaded 13:30 Dhuhr is the first alert.
        #expect(await scheduler.scheduled.first?.fireDate == AlertFixtures.instant("13:30", on: "2026-10-21"))
        #expect(requested.values == [OfflineFixtures.noon])
    }

    @Test func stillReschedulesWhenTheDownloadFails() async throws {
        let store = try await AlertFixtures.store(with: [Fixtures.masjid()])
        let repository = MockMasjidRepository()
        await repository.failNextCall(with: .network)
        let scheduler = MockNotificationScheduler(status: .authorized)
        let refresh = BackgroundRefresh(
            favorites: FavoritesSync(repository: repository, store: store),
            alerts: PrayerAlertSync(store: store, settings: InMemoryPrayerAlertSettingsStore(AlertFixtures.enabled),
                                    scheduler: scheduler, calculator: AlertFixtures.calculator),
            scheduleNext: { _ in }
        )

        await refresh.run(now: OfflineFixtures.noon)

        #expect(await scheduler.scheduled.count == AlertFixtures.alertsFromNoon)
    }
}
