import Foundation

/// Keeps pending prayer alerts in line with the user's favorites, their saved schedules
/// and the alert settings.
struct PrayerAlertSync: Sendable {
    let store: any OfflineStore
    let settings: any PrayerAlertSettingsStore
    let scheduler: any NotificationScheduler
    let calculator: any PrayerTimeCalculator

    /// Replaces the pending alerts. Returns how many are now scheduled.
    @discardableResult
    func reschedule(now: Date) async throws -> Int {
        let current = await settings.load()
        guard current.isEnabled, await scheduler.authorization() == .authorized else {
            try await scheduler.replacePrayerAlerts(with: [])
            return 0
        }
        var schedules: [MasjidSchedule] = []
        for favorite in try await store.favorites() where current[alertsForMasjid: favorite.id] {
            let today = CalendarDay(date: now, in: favorite.masjid.timeZone ?? .current)
            let published = try await store.cachedSchedule(masjidID: favorite.id,
                                                           from: today.adding(days: -1),
                                                           through: today.adding(days: PrayerNotificationPlanner.daysAhead))
            schedules.append(MasjidSchedule(masjid: favorite.masjid, published: published))
        }
        let notifications = PrayerNotificationPlanner.notifications(for: schedules, settings: current,
                                                                    calculator: calculator, now: now)
        try await scheduler.replacePrayerAlerts(with: notifications)
        return notifications.count
    }
}
