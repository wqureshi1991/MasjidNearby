import Foundation

/// Masjids and their published schedules. Implementations throw `RepositoryError`.
protocol MasjidRepository: Sendable {
    /// The masjid this account administers, or nil if it hasn't registered one.
    func masjid(administeredBy adminUID: String) async throws -> Masjid?

    /// Creates an unverified masjid with `adminUID` as its only admin.
    func createMasjid(from draft: MasjidDraft, adminUID: String) async throws -> Masjid

    /// Saves `draft` over `masjid`'s editable details. Admins and verification are unchanged.
    func updateMasjid(_ masjid: Masjid, with draft: MasjidDraft) async throws -> Masjid

    /// Verified masjids within `radiusMeters` of `center`, nearest first.
    func verifiedMasjids(near center: Coordinates, radiusMeters: Double) async throws -> [Masjid]

    /// Published days from `start` through `end`, inclusive.
    func schedule(masjidID: String, from start: CalendarDay, through end: CalendarDay) async throws -> [DailyPrayerTimes]

    /// Writes all `days` in one batch, replacing any existing schedule for those days.
    func publish(_ days: [DailyPrayerTimes], masjidID: String) async throws
}

enum MasjidRepositoryLimits {
    /// Firestore allows 500 writes per batch; stay well under it.
    static let maximumDaysPerPublish = 400
}
