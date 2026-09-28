import SwiftUI

struct AppRootView: View {
    let coordinator: AppCoordinator

    var body: some View {
        Group {
            switch coordinator.flow {
            case .launching:
                ProgressView()
            case .onboarding:
                OnboardingView(coordinator: coordinator)
            case .user(let userCoordinator):
                UserFlowView(coordinator: userCoordinator)
            case .masjidAdmin(let adminCoordinator):
                MasjidAdminFlowView(coordinator: adminCoordinator)
            }
        }
        .task {
            await coordinator.start()
        }
    }
}
