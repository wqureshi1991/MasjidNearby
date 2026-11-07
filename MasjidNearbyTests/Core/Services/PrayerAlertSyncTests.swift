import Foundation
import Testing
@testable import MasjidNearby

struct PrayerAlertSyncTests {
    private func makeSync(store: any OfflineStore,
                          settings: PrayerAlertSettings = AlertFixtures.enabled,
                          scheduler: MockNotificationScheduler = MockNotificationScheduler(status: .authorized)) -> PrayerAlertSync {
        PrayerAlertSync(store: store, settings: InMemoryPrayerAlertSettingsStore(settings),
                        scheduler: scheduler, calculator: AlertFixtures.calculator)
    }

    @Test func schedulesAlertsForFavorites() async throws {
        let scheduler = MockNotificationScheduler(status: .authorized)
        let sync = makeSync(store: try await AlertFixtures.store(with: [Fixtures.masjid()]), scheduler: scheduler)

        let count = try await sync.reschedule(now: OfflineFixtures.noon)

        #expect(count == AlertFixtures.alertsFromNoon)
        #expect(await scheduler.scheduled.count == AlertFixtures.alertsFromNoon)
    }

    @Test func usesSavedTimesOverCalculated() async throws {
        let store = try await AlertFixtures.store(with: [Fixtures.masjid()])
        try await store.replaceSchedule([Fixtures.times(on: "2026-10-21", dhuhr: "13:30", source: .manual)],
                                        masjidID: "m1", syncedAt: OfflineFixtures.noon)
        let scheduler = MockNotificationScheduler(status: .authorized)

        try await makeSync(store: store, scheduler: scheduler).reschedule(now: OfflineFixtures.noon)

        #expect(await scheduler.scheduled.first?.fireDate == AlertFixtures.instant("13:30", on: "2026-10-21"))
    }

    @Test func clearsAlertsWithoutPermission() async throws {
        let scheduler = MockNotificationScheduler(status: .denied)
        let sync = makeSync(store: try await AlertFixtures.store(with: [Fixtures.masjid()]), scheduler: scheduler)

        #expect(try await sync.reschedule(now: OfflineFixtures.noon) == 0)
        #expect(await scheduler.scheduled.isEmpty)
    }

    @Test func clearsAlertsWhenSwitchedOff() async throws {
        let scheduler = MockNotificationScheduler(status: .authorized)
        let sync = makeSync(store: try await AlertFixtures.store(with: [Fixtures.masjid()]),
                            settings: PrayerAlertSettings(), scheduler: scheduler)

        #expect(try await sync.reschedule(now: OfflineFixtures.noon) == 0)
    }

    @Test func skipsMutedMasjids() async throws {
        var settings = AlertFixtures.enabled
        settings[alertsForMasjid: "m1"] = false
        let store = try await AlertFixtures.store(with: [Fixtures.masjid(id: "m1"), Fixtures.masjid(id: "m2")])
        let scheduler = MockNotificationScheduler(status: .authorized)

        try await makeSync(store: store, settings: settings, scheduler: scheduler).reschedule(now: OfflineFixtures.noon)

        #expect(await scheduler.scheduled.allSatisfy { $0.masjidID == "m2" })
    }
}
