import Foundation

/// A masjid the user saved, as stored on the device.
struct FavoriteMasjid: Sendable, Equatable, Identifiable {
    let masjid: Masjid
    let addedAt: Date
    /// When its schedule was last downloaded for offline use.
    let lastSyncedAt: Date?

    var id: String { masjid.id }
}

/// On-device storage for favorites and their cached schedules, so they work without a connection.
protocol OfflineStore: Sendable {
    /// Saved masjids, oldest first.
    func favorites() async throws -> [FavoriteMasjid]
    func isFavorite(masjidID: String) async throws -> Bool
    /// Saves `masjid`, or updates its details if already saved. Keeps the original `addedAt`.
    func saveFavorite(_ masjid: Masjid, at date: Date) async throws
    /// Removes the favorite and its cached schedule.
    func removeFavorite(masjidID: String) async throws
    /// Cached days from `start` through `end`, inclusive, in order.
    func cachedSchedule(masjidID: String, from start: CalendarDay, through end: CalendarDay) async throws -> [DailyPrayerTimes]
    /// Replaces everything cached for `masjidID` with `days` and records `syncedAt` on the favorite.
    func replaceSchedule(_ days: [DailyPrayerTimes], masjidID: String, syncedAt: Date) async throws
}

/// Keeps everything in memory. For tests, and as a fallback if the database can't be opened.
actor InMemoryOfflineStore: OfflineStore {
    private var saved: [String: FavoriteMasjid] = [:]
    private var schedules: [String: [CalendarDay: DailyPrayerTimes]] = [:]

    init() {}

    func favorites() -> [FavoriteMasjid] {
        saved.values.sorted { $0.addedAt < $1.addedAt }
    }

    func isFavorite(masjidID: String) -> Bool {
        saved[masjidID] != nil
    }

    func saveFavorite(_ masjid: Masjid, at date: Date) {
        let existing = saved[masjid.id]
        saved[masjid.id] = FavoriteMasjid(masjid: masjid,
                                          addedAt: existing?.addedAt ?? date,
                                          lastSyncedAt: existing?.lastSyncedAt)
    }

    func removeFavorite(masjidID: String) {
        saved[masjidID] = nil
        schedules[masjidID] = nil
    }

    func cachedSchedule(masjidID: String, from start: CalendarDay, through end: CalendarDay) -> [DailyPrayerTimes] {
        (schedules[masjidID] ?? [:]).values
            .filter { $0.day >= start && $0.day <= end }
            .sorted { $0.day < $1.day }
    }

    func replaceSchedule(_ days: [DailyPrayerTimes], masjidID: String, syncedAt: Date) {
        schedules[masjidID] = Dictionary(days.map { ($0.day, $0) }, uniquingKeysWith: { _, latest in latest })
        if let favorite = saved[masjidID] {
            saved[masjidID] = FavoriteMasjid(masjid: favorite.masjid, addedAt: favorite.addedAt, lastSyncedAt: syncedAt)
        }
    }
}
