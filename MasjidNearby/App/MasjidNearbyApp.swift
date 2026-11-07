import SwiftUI
import UserNotifications

@main
struct MasjidNearbyApp: App {
    @State private var coordinator: AppCoordinator
    /// Held for the app's lifetime: the notification center keeps only a weak reference.
    private let notificationPresenter = NotificationPresenter()

    init() {
        let firebaseConfigured = FirebaseBootstrap.configureIfAvailable()
        _coordinator = State(initialValue: AppCoordinator(dependencies: .makeDefault(firebaseConfigured: firebaseConfigured)))
        UNUserNotificationCenter.current().delegate = notificationPresenter
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(coordinator: coordinator)
        }
    }
}
