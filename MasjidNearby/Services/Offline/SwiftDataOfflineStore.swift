import Foundation
import OSLog
import SwiftData

/// A saved masjid. Details are kept as a JSON snapshot of `Masjid` so the schema
/// doesn't have to mirror every field.
@Model
final class FavoriteMasjidRecord {
    @Attribute(.unique) var masjidID: String
    var masjidData: Data
    var addedAt: Date
    var lastSyncedAt: Date?

    init(masjidID: String, masjidData: Data, addedAt: Date, lastSyncedAt: Date? = nil) {
        self.masjidID = masjidID
        self.masjidData = masjidData
        self.addedAt = addedAt
        self.lastSyncedAt = lastSyncedAt
    }
}

/// One cached day of a favorite's published schedule, as a JSON snapshot of `DailyPrayerTimes`.
@Model
final class CachedScheduleDayRecord {
    /// "masjidID|yyyy-MM-dd".
    @Attribute(.unique) var key: String
    var masjidID: String
    var dayKey: String
    var timesData: Data

    init(masjidID: String, dayKey: String, timesData: Data) {
        self.key = "\(masjidID)|\(dayKey)"
        self.masjidID = masjidID
        self.dayKey = dayKey
        self.timesData = timesData
    }
}

/// SwiftData-backed `OfflineStore`. All model objects stay inside this actor;
/// only `Sendable` domain values go in and out.
@ModelActor
actor SwiftDataOfflineStore: OfflineStore {
    /// The app's on-disk store, or an in-memory one if the database can't be opened.
    static func makeDefault() -> any OfflineStore {
        do {
            let container = try ModelContainer(for: FavoriteMasjidRecord.self, CachedScheduleDayRecord.self)
            return SwiftDataOfflineStore(modelContainer: container)
        } catch {
            Logger(subsystem: "com.waqarqureshi.MasjidNearby", category: "OfflineStore")
                .error("Couldn't open the offline database, so favorites won't persist: \(error.localizedDescription, privacy: .public)")
            return InMemoryOfflineStore()
        }
    }

    func favorites() throws -> [FavoriteMasjid] {
        let decoder = JSONDecoder()
        return try allFavoriteRecords()
            .sorted { $0.addedAt < $1.addedAt }
            .map { record in
                FavoriteMasjid(masjid: try decoder.decode(Masjid.self, from: record.masjidData),
                               addedAt: record.addedAt,
                               lastSyncedAt: record.lastSyncedAt)
            }
    }

    func isFavorite(masjidID: String) throws -> Bool {
        try favoriteRecord(masjidID: masjidID) != nil
    }

    func saveFavorite(_ masjid: Masjid, at date: Date) throws {
        let data = try JSONEncoder().encode(masjid)
        if let existing = try favoriteRecord(masjidID: masjid.id) {
            existing.masjidData = data
        } else {
            modelContext.insert(FavoriteMasjidRecord(masjidID: masjid.id, masjidData: data, addedAt: date))
        }
        try modelContext.save()
    }

    func removeFavorite(masjidID: String) throws {
        if let record = try favoriteRecord(masjidID: masjidID) {
            modelContext.delete(record)
        }
        for record in try scheduleRecords(masjidID: masjidID) {
            modelContext.delete(record)
        }
        try modelContext.save()
    }

    func cachedSchedule(masjidID: String, from start: CalendarDay, through end: CalendarDay) throws -> [DailyPrayerTimes] {
        let decoder = JSONDecoder()
        return try scheduleRecords(masjidID: masjidID)
            .filter { $0.dayKey >= start.key && $0.dayKey <= end.key }
            .map { try decoder.decode(DailyPrayerTimes.self, from: $0.timesData) }
            .sorted { $0.day < $1.day }
    }

    func replaceSchedule(_ days: [DailyPrayerTimes], masjidID: String, syncedAt: Date) throws {
        for record in try scheduleRecords(masjidID: masjidID) {
            modelContext.delete(record)
        }
        let encoder = JSONEncoder()
        for day in days {
            modelContext.insert(CachedScheduleDayRecord(masjidID: masjidID,
                                                        dayKey: day.day.key,
                                                        timesData: try encoder.encode(day)))
        }
        try favoriteRecord(masjidID: masjidID)?.lastSyncedAt = syncedAt
        try modelContext.save()
    }

    // MARK: - Private

    // Fetches everything and filters in Swift: a handful of favorites and a few hundred
    // cached days don't need predicates.

    private func allFavoriteRecords() throws -> [FavoriteMasjidRecord] {
        try modelContext.fetch(FetchDescriptor<FavoriteMasjidRecord>())
    }

    private func favoriteRecord(masjidID: String) throws -> FavoriteMasjidRecord? {
        try allFavoriteRecords().first { $0.masjidID == masjidID }
    }

    private func scheduleRecords(masjidID: String) throws -> [CachedScheduleDayRecord] {
        try modelContext.fetch(FetchDescriptor<CachedScheduleDayRecord>()).filter { $0.masjidID == masjidID }
    }
}
