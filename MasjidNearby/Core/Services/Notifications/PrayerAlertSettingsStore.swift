import Foundation

/// Keeps the user's alert settings.
protocol PrayerAlertSettingsStore: Sendable {
    func load() async -> PrayerAlertSettings
    func save(_ settings: PrayerAlertSettings) async
}
