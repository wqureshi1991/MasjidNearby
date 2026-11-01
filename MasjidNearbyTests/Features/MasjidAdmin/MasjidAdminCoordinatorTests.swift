import Foundation
import Testing
@testable import MasjidNearby

@MainActor
struct MasjidAdminCoordinatorTests {
    @Test func registeringReturnsHomeShowingTheMasjid() async {
        let dependencies = AppDependencies(authService: MockAuthService(), masjidRepository: MockMasjidRepository())
        let coordinator = MasjidAdminCoordinator(session: AuthSession(userID: "admin-1", role: .masjidAdmin),
                                                 dependencies: dependencies, onSignOut: {})
        await coordinator.home.load()

        coordinator.home.registerMasjid()
        #expect(coordinator.path == [.registerMasjid])

        let form = coordinator.makeRegistrationViewModel()
        form.draft = MasjidDraft(masjid: Fixtures.masjid())
        await form.save()

        #expect(coordinator.path.isEmpty)
        #expect(coordinator.home.masjid?.name == "Masjid Al-Noor")

        coordinator.home.editSchedule()
        #expect(coordinator.path.count == 1)
    }
}
