import Foundation
import Testing
@testable import MasjidNearby

@MainActor
struct MasjidFormViewModelTests {
    @Test func registersAMasjidOnceTheFormIsComplete() async throws {
        var saved: Masjid?
        let repository = MockMasjidRepository()
        let viewModel = MasjidFormViewModel(mode: .create(adminUID: "admin-1"), repository: repository,
                                            addressSearch: MockAddressSearchService(), onSaved: { saved = $0 })
        #expect(!viewModel.canSave)

        viewModel.draft.name = "Masjid Al-Noor"
        viewModel.draft.address = "1 Main St, San Jose, CA"
        viewModel.draft.timeZoneIdentifier = "America/Los_Angeles"
        viewModel.useLocation(Fixtures.sanJose)
        #expect(viewModel.canSave)

        await viewModel.save()

        let created = try await repository.masjid(administeredBy: "admin-1")
        #expect(saved != nil)
        #expect(saved == created)
        #expect(saved?.isVerified == false)
        #expect(saved?.coordinates == Fixtures.sanJose)
    }

    @Test func addressSearchSetsTheLocation() async {
        let search = MockAddressSearchService(results: ["1 Main St": Fixtures.sanJose])
        let viewModel = MasjidFormViewModel(mode: .create(adminUID: "admin-1"), repository: MockMasjidRepository(),
                                            addressSearch: search, onSaved: { _ in })
        viewModel.draft.address = "1 Main St"

        await viewModel.findAddress()

        #expect(viewModel.draft.coordinates == Fixtures.sanJose)
        #expect(viewModel.searchMessage == nil)
    }

    @Test func addressWithNoMatchExplainsWhatToDo() async {
        let viewModel = MasjidFormViewModel(mode: .create(adminUID: "admin-1"), repository: MockMasjidRepository(),
                                            addressSearch: MockAddressSearchService(), onSaved: { _ in })
        viewModel.draft.address = "Nowhere"

        await viewModel.findAddress()

        #expect(viewModel.draft.coordinates == nil)
        #expect(viewModel.searchMessage != nil)
    }

    @Test func editModeStartsFromTheMasjidAndSavesChanges() async {
        let masjid = Fixtures.masjid(isVerified: true)
        let repository = MockMasjidRepository(masjids: [masjid], adminUID: "admin-1")
        var saved: Masjid?
        let viewModel = MasjidFormViewModel(mode: .edit(masjid), repository: repository,
                                            addressSearch: MockAddressSearchService(), onSaved: { saved = $0 })
        #expect(viewModel.draft.name == masjid.name)
        #expect(viewModel.draft.makeMasjid(id: masjid.id, isVerified: true) == masjid)

        viewModel.draft.name = "Masjid Al-Noor Community Center"
        await viewModel.save()

        #expect(saved?.name == "Masjid Al-Noor Community Center")
        #expect(saved?.isVerified == true)
        #expect(await repository.storedMasjid(id: masjid.id)?.name == "Masjid Al-Noor Community Center")
    }

    @Test func saveFailureIsShown() async {
        let repository = MockMasjidRepository()
        await repository.failNextCall(with: .permissionDenied)
        let viewModel = MasjidFormViewModel(mode: .edit(Fixtures.masjid()), repository: repository,
                                            addressSearch: MockAddressSearchService(), onSaved: { _ in })

        await viewModel.save()

        #expect(viewModel.saveState.error as? RepositoryError == .permissionDenied)
        #expect(viewModel.canSave)
    }

    @Test func addsAndRemovesJumuahSlots() {
        let viewModel = MasjidFormViewModel(mode: .create(adminUID: "admin-1"), repository: MockMasjidRepository(),
                                            addressSearch: MockAddressSearchService(), onSaved: { _ in })

        viewModel.addJumuahSlot()
        viewModel.addJumuahSlot()
        #expect(viewModel.draft.jumuah.map(\.khutbah) == [Fixtures.time("13:15"), Fixtures.time("14:15")])

        viewModel.removeJumuahSlots(at: IndexSet(integer: 0))
        #expect(viewModel.draft.jumuah.map(\.khutbah) == [Fixtures.time("14:15")])
    }
}
