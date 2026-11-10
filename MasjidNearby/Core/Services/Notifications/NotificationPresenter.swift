import Foundation
import UserNotifications

/// The notification center's delegate: shows prayer alerts as banners while the app is open
/// (iOS hides them otherwise) and passes tapped alerts to `AlertTapRouter`.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    private let router: AlertTapRouter

    init(router: AlertTapRouter) {
        self.router = router
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        guard let masjidID = userInfo[PrayerNotification.masjidIDKey] as? String else { return }
        await router.alertTapped(masjidID: masjidID)
    }
}
