import Foundation

/// Downloads favorites' published schedules into the offline store.
struct FavoritesSync: Sendable {
    /// Days cached ahead of today.
    static let daysAhead = 30

    let repository: any MasjidRepository
    let store: any OfflineStore

    /// The days a refresh covers: yesterday (for an Isha after midnight) through `daysAhead` days out.
    static func window(for masjid: Masjid, now: Date) -> ClosedRange<CalendarDay> {
        let today = CalendarDay(date: now, in: masjid.timeZone ?? .current)
        return today.adding(days: -1)...today.adding(days: daysAhead - 1)
    }

    /// Fetches `masjid`'s published days for the window and replaces its cache with them.
    /// Throws, leaving the old cache in place, if the download fails.
    @discardableResult
    func refresh(_ masjid: Masjid, now: Date) async throws -> [DailyPrayerTimes] {
        let window = Self.window(for: masjid, now: now)
        let days = try await repository.schedule(masjidID: masjid.id, from: window.lowerBound, through: window.upperBound)
        try await store.replaceSchedule(days, masjidID: masjid.id, syncedAt: now)
        return days
    }

    /// Refreshes every favorite. Returns the names of the ones that failed.
    func refreshAll(now: Date) async throws -> [String] {
        var failed: [String] = []
        for favorite in try await store.favorites() {
            do {
                try await refresh(favorite.masjid, now: now)
            } catch {
                failed.append(favorite.masjid.name)
            }
        }
        return failed
    }
}
