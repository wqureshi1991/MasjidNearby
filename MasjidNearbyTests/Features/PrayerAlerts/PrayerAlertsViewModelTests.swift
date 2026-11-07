import Foundation
import Testing
@testable import MasjidNearby

@MainActor
struct PrayerAlertsViewModelTests {
    private func makeViewModel(settings: PrayerAlertSettings = PrayerAlertSettings(),
                               scheduler: MockNotificationScheduler,
                               settingsStore: InMemoryPrayerAlertSettingsStore? = nil) async throws -> PrayerAlertsViewModel {
        let sync = PrayerAlertSync(store: try await AlertFixtures.store(with: [Fixtures.masjid()]),
                                   settings: settingsStore ?? InMemoryPrayerAlertSettingsStore(settings),
                                   scheduler: scheduler, calculator: AlertFixtures.calculator)
        let viewModel = PrayerAlertsViewModel(sync: sync, now: { OfflineFixtures.noon })
        await viewModel.load()
        return viewModel
    }

    @Test func turningAlertsOnAsksPermissionAndSchedules() async throws {
        let scheduler = MockNotificationScheduler(status: .notDetermined, grantsPermission: true)
        let settingsStore = InMemoryPrayerAlertSettingsStore()
        let viewModel = try await makeViewModel(scheduler: scheduler, settingsStore: settingsStore)
        #expect(viewModel.favorites.map(\.id) == ["m1"])

        viewModel.settings.isEnabled = true
        await viewModel.waitForPendingChanges()

        #expect(await scheduler.requestCount == 1)
        #expect(viewModel.authorization == .authorized)
        #expect(await settingsStore.load().isEnabled)
        #expect(viewModel.scheduledCount == AlertFixtures.alertsFromNoon)
        #expect(await scheduler.scheduled.count == AlertFixtures.alertsFromNoon)
    }

    @Test func deniedPermissionLeavesAlertsOff() async throws {
        let scheduler = MockNotificationScheduler(status: .notDetermined, grantsPermission: false)
        let settingsStore = InMemoryPrayerAlertSettingsStore()
        let viewModel = try await makeViewModel(scheduler: scheduler, settingsStore: settingsStore)

        viewModel.settings.isEnabled = true
        await viewModel.waitForPendingChanges()

        #expect(!viewModel.settings.isEnabled)
        #expect(viewModel.isDenied)
        #expect(!(await settingsStore.load().isEnabled))
        #expect(await scheduler.scheduled.isEmpty)
    }

    @Test func choosingPrayersAndMasjidsReschedules() async throws {
        let viewModel = try await makeViewModel(settings: AlertFixtures.enabled,
                                                scheduler: MockNotificationScheduler(status: .authorized))
        #expect(viewModel.scheduledCount == AlertFixtures.alertsFromNoon)

        viewModel.settings[alertsFor: .isha] = false
        await viewModel.waitForPendingChanges()
        // Isha today and on each of the next 6 days.
        #expect(viewModel.scheduledCount == AlertFixtures.alertsFromNoon - 7)

        viewModel.settings[alertsForMasjid: "m1"] = false
        await viewModel.waitForPendingChanges()
        #expect(viewModel.scheduledCount == 0)
    }
}
