import SwiftUI

@main
struct MasjidNearbyApp: App {
    @State private var coordinator: AppCoordinator

    init() {
        FirebaseBootstrap.configureIfAvailable()
        _coordinator = State(initialValue: AppCoordinator(dependencies: .makeDefault()))
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(coordinator: coordinator)
        }
    }
}
