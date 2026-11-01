import Foundation
import Testing
@testable import MasjidNearby

@MainActor
struct AdminHomeViewModelTests {
    @Test func adminWithoutAMasjidIsAskedToRegister() async {
        var registerTapped = false
        let viewModel = AdminHomeViewModel(adminUID: "admin-1", repository: MockMasjidRepository())
        viewModel.onRegister = { registerTapped = true }

        await viewModel.load()
        viewModel.registerMasjid()

        #expect(viewModel.state.isLoaded)
        #expect(viewModel.masjid == nil)
        #expect(registerTapped)
    }

    @Test func loadsTheAdminsMasjid() async {
        var scheduleFor: Masjid?
        let masjid = Fixtures.masjid()
        let viewModel = AdminHomeViewModel(adminUID: "admin-1",
                                           repository: MockMasjidRepository(masjids: [masjid], adminUID: "admin-1"))
        viewModel.onEditSchedule = { scheduleFor = $0 }

        await viewModel.load()
        viewModel.editSchedule()

        #expect(viewModel.masjid == masjid)
        #expect(scheduleFor == masjid)
    }

    @Test func failedFirstLoadShowsTheError() async {
        let repository = MockMasjidRepository()
        await repository.failNextCall(with: .network)
        let viewModel = AdminHomeViewModel(adminUID: "admin-1", repository: repository)

        await viewModel.load()

        #expect(viewModel.state.error as? RepositoryError == .network)
    }

    @Test func failedRefreshKeepsTheMasjid() async {
        let masjid = Fixtures.masjid()
        let repository = MockMasjidRepository(masjids: [masjid], adminUID: "admin-1")
        let viewModel = AdminHomeViewModel(adminUID: "admin-1", repository: repository)
        await viewModel.load()
        await repository.failNextCall(with: .network)

        await viewModel.load()

        #expect(viewModel.masjid == masjid)
    }
}
