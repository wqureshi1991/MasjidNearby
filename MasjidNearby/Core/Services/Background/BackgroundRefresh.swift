import BackgroundTasks
import Foundation
import OSLog

/// Refreshes favorites' schedules and prayer alerts while the app is closed, so alerts keep
/// coming even when the app isn't opened for a while.
struct BackgroundRefresh: Sendable {
    /// Must match `BGTaskSchedulerPermittedIdentifiers` in Config/MasjidNearby-Info.plist.
    static let taskIdentifier = "com.waqarqureshi.MasjidNearby.refresh"
    /// Alerts cover about a week ahead; asking twice a day keeps well clear of running out.
    /// iOS decides the real timing from how the app is used.
    static let interval: TimeInterval = 12 * 3_600

    private static let logger = Logger(subsystem: "com.waqarqureshi.MasjidNearby", category: "BackgroundRefresh")

    let favorites: FavoritesSync
    let alerts: PrayerAlertSync
    /// Asks iOS for the next run. Replaced in tests.
    let scheduleNext: @Sendable (Date) -> Void

    init(favorites: FavoritesSync,
         alerts: PrayerAlertSync,
         scheduleNext: @escaping @Sendable (Date) -> Void = { BackgroundRefresh.schedule(after: $0) }) {
        self.favorites = favorites
        self.alerts = alerts
        self.scheduleNext = scheduleNext
    }

    init(dependencies: AppDependencies) {
        self.init(
            favorites: FavoritesSync(repository: dependencies.masjidRepository, store: dependencies.offlineStore),
            alerts: PrayerAlertSync(
                store: dependencies.offlineStore,
                settings: dependencies.alertSettingsStore,
                scheduler: dependencies.notificationScheduler,
                calculator: dependencies.prayerTimeCalculator
            )
        )
    }

    /// One background run. Asks for the next run first, in case iOS cuts this one short.
    func run(now: Date = Date()) async {
        scheduleNext(now)
        do {
            let failed = try await favorites.refreshAll(now: now)
            if !failed.isEmpty {
                Self.logger.notice("Couldn't refresh \(failed.count) favorites; using saved times.")
            }
        } catch {
            Self.logger.error("Couldn't read favorites: \(error.localizedDescription, privacy: .public)")
        }
        do {
            try await alerts.reschedule(now: now)
        } catch {
            Self.logger.error("Couldn't reschedule alerts: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Asks iOS to run the refresh no earlier than `interval` after `date`.
    static func schedule(after date: Date = Date()) {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = date.addingTimeInterval(interval)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Expected in the simulator and when Background App Refresh is off.
            logger.notice("Background refresh not scheduled: \(error.localizedDescription, privacy: .public)")
        }
    }
}
