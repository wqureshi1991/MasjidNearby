import Foundation

/// Schedules prayer alerts with the system.
protocol NotificationScheduler: Sendable {
    func authorization() async -> NotificationAuthorization
    /// Shows the system prompt if the user hasn't been asked yet. Returns whether alerts are allowed.
    func requestAuthorization() async throws -> Bool
    /// Replaces every pending prayer alert with `notifications`, leaving other notifications alone.
    func replacePrayerAlerts(with notifications: [PrayerNotification]) async throws
}
