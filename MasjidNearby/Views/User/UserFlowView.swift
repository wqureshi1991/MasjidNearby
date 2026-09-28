import SwiftUI

struct UserFlowView: View {
    @Bindable var coordinator: UserCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            List {
                Section("Nearby") {
                    Button("Sample Masjid") {
                        coordinator.showMasjidDetail(masjidID: "sample")
                    }
                }
            }
            .navigationTitle("Masjids")
            .toolbar {
                Button("Sign Out") {
                    Task { await coordinator.signOut() }
                }
            }
            .navigationDestination(for: UserCoordinator.Route.self) { route in
                switch route {
                case .masjidDetail(let masjidID):
                    Text("Masjid \(masjidID)")
                        .navigationTitle("Prayer Times")
                }
            }
        }
    }
}
