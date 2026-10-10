import SwiftUI

@main
struct MasjidNearbyApp: App {
    @State private var coordinator: AppCoordinator

    init() {
        let firebaseConfigured = FirebaseBootstrap.configureIfAvailable()
        _coordinator = State(initialValue: AppCoordinator(dependencies: .makeDefault(firebaseConfigured: firebaseConfigured)))
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(coordinator: coordinator)
        }
    }
}
