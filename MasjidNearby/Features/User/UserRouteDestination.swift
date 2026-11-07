import SwiftUI

/// The screen for a route pushed in either tab.
struct UserRouteDestination: View {
    let route: UserCoordinator.Route
    let coordinator: UserCoordinator

    var body: some View {
        switch route {
        case .masjidDetail(let masjid, let distanceMeters):
            MasjidDetailView(viewModel: coordinator.makeDetailViewModel(masjid: masjid, distanceMeters: distanceMeters))
        case .prayerAlerts:
            PrayerAlertsView(viewModel: coordinator.makePrayerAlertsViewModel())
        }
    }
}
