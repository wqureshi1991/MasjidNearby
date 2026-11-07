import Foundation

/// Alert settings in `UserDefaults`, as JSON.
struct UserDefaultsPrayerAlertSettingsStore: PrayerAlertSettingsStore {
    static let key = "prayerAlertSettings"

    func load() -> PrayerAlertSettings {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let settings = try? JSONDecoder().decode(PrayerAlertSettings.self, from: data)
        else { return PrayerAlertSettings() }
        return settings
    }

    func save(_ settings: PrayerAlertSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
