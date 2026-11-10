import Foundation
import UserNotifications

/// Local notifications through `UNUserNotificationCenter`.
struct UserNotificationScheduler: NotificationScheduler {
    func authorization() async -> NotificationAuthorization {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        @unknown default:
            return .denied
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func replacePrayerAlerts(with notifications: [PrayerNotification]) async throws {
        let center = UNUserNotificationCenter.current()
        let stale = await center.pendingNotificationRequests()
            .map { $0.identifier }
            .filter { $0.hasPrefix(PrayerNotification.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: stale)
        for notification in notifications {
            try await center.add(Self.request(for: notification))
        }
    }

    private static func request(for notification: PrayerNotification) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        content.threadIdentifier = notification.masjidID
        content.userInfo = [PrayerNotification.masjidIDKey: notification.masjidID]

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = notification.timeZone
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notification.fireDate)
        components.timeZone = notification.timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: notification.id, content: content, trigger: trigger)
    }
}
