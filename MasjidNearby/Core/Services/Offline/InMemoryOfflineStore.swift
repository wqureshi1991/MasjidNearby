import Foundation

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
