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
                                signOutButton
                            }
                        }
                        .navigationDestination(for: UserCoordinator.Route.self) { route in
                            destination(for: route)
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
                            destination(for: route)
                        }
                }
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            Task { await coordinator.rescheduleAlerts() }
        }
    }

    private var signOutButton: some View {
        Button(coordinator.session.isGuest ? "Exit" : "Sign Out") {
            Task { await coordinator.signOut() }
        }
    }

    @ViewBuilder
    private func destination(for route: UserCoordinator.Route) -> some View {
        switch route {
        case .masjidDetail(let masjid, let distanceMeters):
            MasjidDetailView(viewModel: coordinator.makeDetailViewModel(masjid: masjid, distanceMeters: distanceMeters))
        case .prayerAlerts:
            PrayerAlertsView(viewModel: coordinator.makePrayerAlertsViewModel())
        }
    }
}
