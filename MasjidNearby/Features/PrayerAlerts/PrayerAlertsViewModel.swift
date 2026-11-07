import Foundation
import Observation

/// The Prayer Alerts screen: turning alerts on, and choosing prayers and masjids.
/// Every change is saved and the pending alerts rescheduled straight away.
@MainActor
@Observable
final class PrayerAlertsViewModel {
    private(set) var authorization: NotificationAuthorization = .notDetermined
    private(set) var favorites: [Masjid] = []
    private(set) var scheduledCount = 0
    private(set) var message: String?

    private var storedSettings = PrayerAlertSettings()
    @ObservationIgnored private var pendingChange: Task<Void, Never>?

    private let sync: PrayerAlertSync
    private let now: @Sendable () -> Date

    init(sync: PrayerAlertSync, now: @escaping @Sendable () -> Date = { Date() }) {
        self.sync = sync
        self.now = now
    }

    /// Views bind straight to these fields. Turning alerts on asks for permission first.
    var settings: PrayerAlertSettings {
        get { storedSettings }
        set {
            let previous = storedSettings
            guard newValue != previous else { return }
            storedSettings = newValue
            let earlier = pendingChange
            pendingChange = Task {
                await earlier?.value
                await commit(from: previous)
            }
        }
    }

    var isDenied: Bool { authorization == .denied }

    var statusText: String {
        if isDenied {
            return "Notifications are off for Masjid Nearby. Turn them on in Settings, then come back."
        }
        guard settings.isEnabled else {
            return "Get an alert at adhan time for your favorite masjids."
        }
        return switch scheduledCount {
        case 0: "No alerts scheduled. Choose at least one prayer and masjid."
        case 1: "1 alert scheduled."
        default: "\(scheduledCount) alerts scheduled for the coming days."
        }
    }

    func load() async {
        storedSettings = await sync.settings.load()
        authorization = await sync.scheduler.authorization()
        do {
            favorites = try await sync.store.favorites().map { $0.masjid }
        } catch {
            message = "Couldn't load favorites: \(error.localizedDescription)"
        }
        await reschedule()
    }

    /// Waits for saved changes to be applied. For tests.
    func waitForPendingChanges() async {
        await pendingChange?.value
    }

    // MARK: - Private

    private func commit(from previous: PrayerAlertSettings) async {
        if storedSettings.isEnabled && !previous.isEnabled {
            let granted = (try? await sync.scheduler.requestAuthorization()) ?? false
            authorization = await sync.scheduler.authorization()
            if !granted {
                storedSettings.isEnabled = false
            }
        }
        await sync.settings.save(storedSettings)
        await reschedule()
    }

    private func reschedule() async {
        do {
            scheduledCount = try await sync.reschedule(now: now())
            message = nil
        } catch {
            message = "Couldn't schedule alerts: \(error.localizedDescription)"
        }
    }
}
