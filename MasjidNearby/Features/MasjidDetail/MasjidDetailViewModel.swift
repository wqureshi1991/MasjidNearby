import Foundation
import Observation

/// Today's times at one masjid, and which prayer is next.
@MainActor
@Observable
final class MasjidDetailViewModel {
    struct Schedule: Sendable, Equatable {
        let today: DailyPrayerTimes
        /// Needed after Isha, to show tomorrow's Fajr as next.
        let tomorrow: DailyPrayerTimes?
    }

    let masjid: Masjid
    let distanceMeters: Double?
    let timeZone: TimeZone
    private(set) var state: LoadState<Schedule> = .idle
    /// Set when published times couldn't be loaded and saved or calculated times are shown instead.
    private(set) var notice: String? = nil
    private(set) var isFavorite = false
    /// Set when saving or removing the favorite fails.
    private(set) var favoriteError: String? = nil

    /// Called after the masjid is saved or removed, so the favorites list can refresh.
    @ObservationIgnored var onFavoritesChanged: (@MainActor () -> Void)?

    private let repository: any MasjidRepository
    private let favorites: FavoritesSync?
    private let resolver: PrayerTimeResolver
    private let now: @Sendable () -> Date

    init(masjid: Masjid,
         distanceMeters: Double?,
         repository: any MasjidRepository,
         calculator: any PrayerTimeCalculator,
         favorites: FavoritesSync? = nil,
         now: @escaping @Sendable () -> Date = { Date() }) {
        self.masjid = masjid
        self.distanceMeters = distanceMeters
        self.timeZone = masjid.timeZone ?? .current
        self.repository = repository
        self.favorites = favorites
        self.resolver = PrayerTimeResolver(calculator: calculator)
        self.now = now
    }

    func load() async {
        guard !state.isLoading else { return }
        let today = CalendarDay(date: now(), in: timeZone)
        let tomorrow = today.adding(days: 1)
        let previous = state
        state = .loading

        isFavorite = await loadIsFavorite()

        var published: [CalendarDay: DailyPrayerTimes] = [:]
        do {
            let days: [DailyPrayerTimes]
            if isFavorite, let favorites {
                // Favorites keep a 30-day cache for offline use; refresh it while we're here.
                days = try await favorites.refresh(masjid, now: now())
                await refreshSavedDetails(in: favorites)
            } else {
                days = try await repository.schedule(masjidID: masjid.id, from: today, through: tomorrow)
            }
            published = Self.byDay(days)
            notice = nil
        } catch {
            let saved = await savedDays(from: today, through: tomorrow)
            if let syncedAt = saved.syncedAt, !saved.days.isEmpty {
                published = Self.byDay(saved.days)
                notice = "You're offline. Showing times saved \(syncedAt.formatted(.relative(presentation: .named)))."
            } else {
                notice = "Couldn't load this masjid's published times, so calculated times are shown. Pull to refresh."
            }
        }

        do {
            let todayTimes = try resolver.times(for: masjid, on: today, published: published[today])
            let tomorrowTimes = try resolver.times(for: masjid, on: tomorrow, published: published[tomorrow])
            state = .loaded(Schedule(today: todayTimes, tomorrow: tomorrowTimes))
        } catch {
            if case .loaded = previous {
                state = previous
            } else {
                state = .failed(error)
            }
        }
    }

    // MARK: - Favorites

    func toggleFavorite() async {
        guard let favorites else { return }
        favoriteError = nil
        do {
            if isFavorite {
                try await favorites.store.removeFavorite(masjidID: masjid.id)
                isFavorite = false
            } else {
                try await favorites.store.saveFavorite(masjid, at: now())
                isFavorite = true
                do {
                    try await favorites.refresh(masjid, now: now())
                } catch {
                    favoriteError = "Saved. Times will be stored for offline use next time you're online."
                }
            }
            onFavoritesChanged?()
        } catch {
            favoriteError = "Couldn't update favorites: \(error.localizedDescription)"
        }
    }

    var canFavorite: Bool { favorites != nil }

    // MARK: - Display

    var schedule: Schedule? {
        if case .loaded(let schedule) = state { schedule } else { nil }
    }

    /// True when today's times are calculated, because the masjid hasn't published them.
    var isTodayCalculated: Bool {
        schedule?.today.source == .calculated
    }

    func upcoming(at date: Date) -> UpcomingPrayer? {
        guard let schedule else { return nil }
        return NextPrayerFinder.next(after: date, today: schedule.today, tomorrow: schedule.tomorrow, in: timeZone)
    }

    /// "5:42 AM", in the masjid's time zone and the user's locale.
    func formatted(_ time: WallClockTime) -> String {
        let day = schedule?.today.day ?? CalendarDay(date: now(), in: timeZone)
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = timeZone
        return time.instant(on: day, in: timeZone).formatted(style)
    }

    /// "Updated by the masjid 3 days ago", for published times that carry a timestamp.
    var lastUpdatedText: String? {
        guard let schedule, schedule.today.source != .calculated, let updatedAt = schedule.today.updatedAt else {
            return nil
        }
        return "Updated by the masjid \(updatedAt.formatted(.relative(presentation: .named)))."
    }

    var formattedDistance: String? {
        distanceMeters.map {
            Measurement(value: $0, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated, usage: .road))
        }
    }

    /// Opens Apple Maps with directions to the masjid.
    var directionsURL: URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "maps.apple.com"
        components.path = "/"
        components.queryItems = [
            URLQueryItem(name: "daddr", value: "\(masjid.coordinates.latitude),\(masjid.coordinates.longitude)"),
            URLQueryItem(name: "q", value: masjid.name),
        ]
        return components.url
    }

    // MARK: - Private

    /// Keeps the saved copy of the masjid's details current. Best effort: the old copy is still usable.
    private func refreshSavedDetails(in favorites: FavoritesSync) async {
        do {
            try await favorites.store.saveFavorite(masjid, at: now())
        } catch {
            return
        }
    }

    private func loadIsFavorite() async -> Bool {
        guard let favorites else { return false }
        do {
            return try await favorites.store.isFavorite(masjidID: masjid.id)
        } catch {
            return false
        }
    }

    /// Cached days for a favorite, and when they were saved. Empty when nothing is cached.
    private func savedDays(from start: CalendarDay, through end: CalendarDay) async -> (days: [DailyPrayerTimes], syncedAt: Date?) {
        guard isFavorite, let favorites else { return ([], nil) }
        do {
            let days = try await favorites.store.cachedSchedule(masjidID: masjid.id, from: start, through: end)
            let syncedAt = try await favorites.store.favorites().first { $0.masjid.id == masjid.id }?.lastSyncedAt
            return (days, syncedAt)
        } catch {
            return ([], nil)
        }
    }

    private static func byDay(_ days: [DailyPrayerTimes]) -> [CalendarDay: DailyPrayerTimes] {
        Dictionary(days.map { ($0.day, $0) }, uniquingKeysWith: { _, latest in latest })
    }
}
