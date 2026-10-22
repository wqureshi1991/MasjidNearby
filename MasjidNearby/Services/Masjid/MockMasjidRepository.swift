import Foundation

/// In-memory masjids and schedules. Used by tests, and by the app when Firebase isn't configured.
actor MockMasjidRepository: MasjidRepository {
    private var masjids: [String: Masjid] = [:]
    private var admins: [String: String] = [:]   // masjid ID → admin UID
    private var schedules: [String: [CalendarDay: DailyPrayerTimes]] = [:]
    private var nextError: RepositoryError?
    private(set) var publishCallCount = 0

    init(masjids: [Masjid] = [], adminUID: String? = nil) {
        for masjid in masjids {
            self.masjids[masjid.id] = masjid
            if let adminUID {
                admins[masjid.id] = adminUID
            }
        }
    }

    func masjid(administeredBy adminUID: String) throws -> Masjid? {
        try throwInjectedError()
        guard let id = admins.first(where: { $0.value == adminUID })?.key else { return nil }
        return masjids[id]
    }

    func createMasjid(from draft: MasjidDraft, adminUID: String) throws -> Masjid {
        try throwInjectedError()
        guard let masjid = draft.makeMasjid(id: "masjid-\(masjids.count + 1)", isVerified: false) else {
            throw RepositoryError.invalidData("the masjid details are incomplete")
        }
        masjids[masjid.id] = masjid
        admins[masjid.id] = adminUID
        return masjid
    }

    func updateMasjid(_ masjid: Masjid, with draft: MasjidDraft) throws -> Masjid {
        try throwInjectedError()
        guard masjids[masjid.id] != nil else { throw RepositoryError.notFound }
        guard let updated = draft.makeMasjid(id: masjid.id, isVerified: masjid.isVerified) else {
            throw RepositoryError.invalidData("the masjid details are incomplete")
        }
        masjids[masjid.id] = updated
        return updated
    }

    func schedule(masjidID: String, from start: CalendarDay, through end: CalendarDay) throws -> [DailyPrayerTimes] {
        try throwInjectedError()
        return (schedules[masjidID] ?? [:]).values
            .filter { $0.day >= start && $0.day <= end }
            .sorted { $0.day < $1.day }
    }

    func publish(_ days: [DailyPrayerTimes], masjidID: String) throws {
        try throwInjectedError()
        publishCallCount += 1
        var schedule = schedules[masjidID] ?? [:]
        for day in days {
            schedule[day.day] = day
        }
        schedules[masjidID] = schedule
    }

    // MARK: - Test hooks

    func failNextCall(with error: RepositoryError) {
        nextError = error
    }

    func storedMasjid(id: String) -> Masjid? {
        masjids[id]
    }

    private func throwInjectedError() throws {
        guard let error = nextError else { return }
        nextError = nil
        throw error
    }
}
