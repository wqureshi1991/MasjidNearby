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
    /// Set when published times couldn't be loaded and calculated times are shown instead.
    private(set) var notice: String? = nil

    private let repository: any MasjidRepository
    private let resolver: PrayerTimeResolver
    private let now: @Sendable () -> Date

    init(masjid: Masjid,
         distanceMeters: Double?,
         repository: any MasjidRepository,
         calculator: any PrayerTimeCalculator,
         now: @escaping @Sendable () -> Date = { Date() }) {
        self.masjid = masjid
        self.distanceMeters = distanceMeters
        self.timeZone = masjid.timeZone ?? .current
        self.repository = repository
        self.resolver = PrayerTimeResolver(calculator: calculator)
        self.now = now
    }

    func load() async {
        guard !state.isLoading else { return }
        let today = CalendarDay(date: now(), in: timeZone)
        let tomorrow = today.adding(days: 1)
        let previous = state
        state = .loading

        var published: [CalendarDay: DailyPrayerTimes] = [:]
        do {
            let days = try await repository.schedule(masjidID: masjid.id, from: today, through: tomorrow)
            published = Dictionary(days.map { ($0.day, $0) }, uniquingKeysWith: { _, latest in latest })
            notice = nil
        } catch {
            notice = "Couldn't load this masjid's published times, so calculated times are shown. Pull to refresh."
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
}
