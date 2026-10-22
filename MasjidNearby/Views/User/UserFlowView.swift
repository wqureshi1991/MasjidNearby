import SwiftUI

struct UserFlowView: View {
    @Bindable var coordinator: UserCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            NearbyMasjidsView(viewModel: coordinator.nearby)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(coordinator.session.isGuest ? "Exit" : "Sign Out") {
                            Task { await coordinator.signOut() }
                        }
                    }
                }
                .navigationDestination(for: UserCoordinator.Route.self) { route in
                    switch route {
                    case .masjidDetail(let masjid, let distanceMeters):
                        MasjidDetailView(viewModel: coordinator.makeDetailViewModel(masjid: masjid,
                                                                                    distanceMeters: distanceMeters))
                    }
                }
        }
    }
}
