import Foundation

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
