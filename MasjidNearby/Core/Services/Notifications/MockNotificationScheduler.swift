import Foundation

/// Records alerts instead of scheduling them. For tests and previews.
actor MockNotificationScheduler: NotificationScheduler {
    private(set) var status: NotificationAuthorization
    private(set) var scheduled: [PrayerNotification] = []
    private(set) var requestCount = 0
    private let grantsPermission: Bool

    init(status: NotificationAuthorization = .notDetermined, grantsPermission: Bool = true) {
        self.status = status
        self.grantsPermission = grantsPermission
    }

    func authorization() -> NotificationAuthorization {
        status
    }

    func requestAuthorization() -> Bool {
        requestCount += 1
        if status == .notDetermined {
            status = grantsPermission ? .authorized : .denied
        }
        return status == .authorized
    }

    func replacePrayerAlerts(with notifications: [PrayerNotification]) {
        scheduled = notifications
    }
}
