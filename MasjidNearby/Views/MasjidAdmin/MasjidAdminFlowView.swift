import SwiftUI

struct MasjidAdminFlowView: View {
    @Bindable var coordinator: MasjidAdminCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            List {
                Section("Prayer Times") {
                    Button("Edit Schedule") {
                        coordinator.showScheduleEditor()
                    }
                }
            }
            .navigationTitle("My Masjid")
            .toolbar {
                Button("Sign Out") {
                    Task { await coordinator.signOut() }
                }
            }
            .navigationDestination(for: MasjidAdminCoordinator.Route.self) { route in
                switch route {
                case .scheduleEditor:
                    Text("Schedule editor")
                        .navigationTitle("Schedule")
                }
            }
        }
    }
}
