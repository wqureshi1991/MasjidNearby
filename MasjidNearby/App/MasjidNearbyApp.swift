import SwiftUI
import UserNotifications

@main
struct MasjidNearbyApp: App {
    @State private var coordinator: AppCoordinator
    @Environment(\.scenePhase) private var scenePhase
    /// Held for the app's lifetime: the notification center keeps only a weak reference.
    private let notificationPresenter = NotificationPresenter()
    private let backgroundRefresh: BackgroundRefresh

    init() {
        let firebaseConfigured = FirebaseBootstrap.configureIfAvailable()
        let dependencies = AppDependencies.makeDefault(firebaseConfigured: firebaseConfigured)
        backgroundRefresh = BackgroundRefresh(dependencies: dependencies)
        _coordinator = State(initialValue: AppCoordinator(dependencies: dependencies))
        UNUserNotificationCenter.current().delegate = notificationPresenter
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(coordinator: coordinator)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                BackgroundRefresh.schedule()
            }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.taskIdentifier)) { [backgroundRefresh] in
            await backgroundRefresh.run()
        }
    }
}
