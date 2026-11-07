import SwiftUI

struct UserFlowView: View {
    @Bindable var coordinator: UserCoordinator

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
                        .navigationDestination(for: UserCoordinator.Route.self) { route in
                            destination(for: route)
                        }
                }
            }
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
        }
    }
}
