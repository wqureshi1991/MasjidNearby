import Foundation

/// Alert settings held in memory. For tests and previews.
actor InMemoryPrayerAlertSettingsStore: PrayerAlertSettingsStore {
    private var settings: PrayerAlertSettings

    init(_ settings: PrayerAlertSettings = PrayerAlertSettings()) {
        self.settings = settings
    }

    func load() -> PrayerAlertSettings {
        settings
    }

    func save(_ settings: PrayerAlertSettings) {
        self.settings = settings
    }
}
