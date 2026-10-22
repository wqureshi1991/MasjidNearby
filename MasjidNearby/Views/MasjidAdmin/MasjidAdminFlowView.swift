import SwiftUI

struct MasjidAdminFlowView: View {
    @Bindable var coordinator: MasjidAdminCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            AdminHomeView(viewModel: coordinator.home)
                .toolbar {
                    Button("Sign Out") {
                        Task { await coordinator.signOut() }
                    }
                }
                .navigationDestination(for: MasjidAdminCoordinator.Route.self) { route in
                    switch route {
                    case .registerMasjid:
                        MasjidFormView(viewModel: coordinator.makeRegistrationViewModel())
                    case .editMasjid(let masjid):
                        MasjidFormView(viewModel: coordinator.makeEditViewModel(for: masjid))
                    case .schedule(let masjid):
                        ScheduleEditorView(viewModel: coordinator.makeScheduleEditorViewModel(for: masjid))
                    }
                }
        }
    }
}
