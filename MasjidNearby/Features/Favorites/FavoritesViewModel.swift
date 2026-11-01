import Foundation
import Observation

/// The user's saved masjids. Loads from the device first, so it works offline,
/// then refreshes their schedules from the network.
@MainActor
@Observable
final class FavoritesViewModel {
    struct Item: Identifiable, Sendable, Equatable {
        let masjid: Masjid
        /// Today's times: saved published times, or calculated if none are saved.
        let today: DailyPrayerTimes?
        let lastSyncedAt: Date?

        var id: String { masjid.id }
    }

    private(set) var state: LoadState<[Item]> = .idle
    private(set) var isRefreshing = false
    /// Set when some favorites couldn't be refreshed; their saved times are still shown.
    private(set) var refreshMessage: String? = nil

    @ObservationIgnored var onSelect: (@MainActor (Masjid) -> Void)?

    private let sync: FavoritesSync
    private let resolver: PrayerTimeResolver
    private let now: @Sendable () -> Date

    init(sync: FavoritesSync,
         calculator: any PrayerTimeCalculator,
         now: @escaping @Sendable () -> Date = { Date() }) {
        self.sync = sync
        self.resolver = PrayerTimeResolver(calculator: calculator)
        self.now = now
    }

    /// Reads favorites and their saved times from the device. No network.
    func load() async {
        do {
            let favorites = try await sync.store.favorites()
            var items: [Item] = []
            for favorite in favorites {
                items.append(await makeItem(for: favorite))
            }
            state = .loaded(items)
        } catch {
            state = .failed(error)
        }
    }

    /// Downloads fresh schedules for every favorite, then reloads from the device.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let failed = try await sync.refreshAll(now: now())
            refreshMessage = failed.isEmpty
                ? nil
                : "Couldn't update \(failed.joined(separator: ", ")). Showing saved times."
        } catch {
            refreshMessage = "Couldn't update favorites: \(error.localizedDescription)"
        }
        await load()
    }

    func remove(_ item: Item) async {
        do {
            try await sync.store.removeFavorite(masjidID: item.id)
        } catch {
            refreshMessage = "Couldn't remove \(item.masjid.name): \(error.localizedDescription)"
        }
        await load()
    }

    func select(_ item: Item) {
        onSelect?(item.masjid)
    }

    func upcoming(for item: Item, at date: Date) -> UpcomingPrayer? {
        guard let today = item.today else { return nil }
        return NextPrayerFinder.next(after: date, today: today, tomorrow: nil, in: item.masjid.timeZone ?? .current)
    }

    func formatted(_ date: Date, for item: Item) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = item.masjid.timeZone ?? .current
        return date.formatted(style)
    }

    // MARK: - Private

    private func makeItem(for favorite: FavoriteMasjid) async -> Item {
        let masjid = favorite.masjid
        let today = CalendarDay(date: now(), in: masjid.timeZone ?? .current)
        var saved: DailyPrayerTimes?
        do {
            saved = try await sync.store.cachedSchedule(masjidID: masjid.id, from: today, through: today).first
        } catch {
            saved = nil
        }
        let times: DailyPrayerTimes?
        do {
            times = try resolver.times(for: masjid, on: today, published: saved)
        } catch {
            times = nil
        }
        return Item(masjid: masjid, today: times, lastSyncedAt: favorite.lastSyncedAt)
    }
}
