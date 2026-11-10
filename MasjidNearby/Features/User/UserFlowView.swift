import SwiftUI

struct UserFlowView: View {
    @Bindable var coordinator: UserCoordinator
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            Tab("Nearby", systemImage: "location", value: UserCoordinator.Tab.nearby) {
                NavigationStack(path: $coordinator.path) {
                    NearbyMasjidsView(viewModel: coordinator.nearby)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                SignOutButton(coordinator: coordinator)
                            }
                        }
                        .navigationDestination(for: UserCoordinator.Route.self) { route in
                            UserRouteDestination(route: route, coordinator: coordinator)
                        }
                }
            }

            Tab("Favorites", systemImage: "star", value: UserCoordinator.Tab.favorites) {
                NavigationStack(path: $coordinator.favoritesPath) {
                    FavoritesView(viewModel: coordinator.favorites)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Prayer Alerts", systemImage: "bell") {
                                    coordinator.showPrayerAlerts()
                                }
                                .labelStyle(.iconOnly)
                            }
                        }
                        .navigationDestination(for: UserCoordinator.Route.self) { route in
                            UserRouteDestination(route: route, coordinator: coordinator)
                        }
                }
            }
        }
        .onChange(of: coordinator.alertTaps.pendingMasjidID, initial: true) { _, masjidID in
            guard masjidID != nil else { return }
            Task { await coordinator.openPendingAlert() }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            Task { await coordinator.rescheduleAlerts() }
        }
    }
}
