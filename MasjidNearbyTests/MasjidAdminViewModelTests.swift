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

@MainActor
struct ScheduleEditorViewModelTests {
    /// 2026-10-21 18:00 UTC: 11:00 on 21 October in California.
    private let now = Fixtures.day("2026-10-21").startOfDayUTC.addingTimeInterval(18 * 3_600)

    @Test func startsTodayInTheMasjidsTimeZoneWithCalculatedTimes() {
        let viewModel = makeViewModel()

        #expect(viewModel.selectedDay.key == "2026-10-21")
        #expect(viewModel.lastDay.key == "2026-12-19")
        #expect(viewModel.selectedDayStatus == .calculated)
        #expect(viewModel.editingDay.fajr.adhan == Fixtures.time("05:53"))
        #expect(!viewModel.canGoBack)
        #expect(!viewModel.canPublish)
    }

    @Test func editingMarksTheDayAndRevertingClearsIt() {
        let viewModel = makeViewModel()

        viewModel.editingDay.fajr.hasIqamah = true
        #expect(viewModel.selectedDayStatus == .edited)
        #expect(viewModel.editedDayCount == 1)
        #expect(viewModel.canPublish)

        viewModel.revertSelectedDay()
        #expect(viewModel.selectedDayStatus == .calculated)
        #expect(viewModel.editedDayCount == 0)
    }

    @Test func editingBackToTheBaselineIsNotAnEdit() {
        let viewModel = makeViewModel()

        viewModel.editingDay.dhuhr.adhan = Fixtures.time("13:30")
        viewModel.editingDay.dhuhr.adhan = Fixtures.time("12:57")

        #expect(viewModel.editedDayCount == 0)
    }

    @Test func switchingDaysKeepsEdits() {
        let viewModel = makeViewModel()
        viewModel.editingDay.fajr.hasIqamah = true
        viewModel.editingDay.fajr.iqamah = Fixtures.time("06:20")

        viewModel.goToNextDay()
        #expect(viewModel.selectedDayStatus == .calculated)
        #expect(!viewModel.editingDay.fajr.hasIqamah)

        viewModel.goToPreviousDay()
        #expect(viewModel.selectedDayStatus == .edited)
        #expect(viewModel.editingDay.fajr.prayerTime.iqamah == Fixtures.time("06:20"))
    }

    @Test func selectionStaysInsideTheWindow() {
        let viewModel = makeViewModel()

        viewModel.selectedDay = viewModel.lastDay.adding(days: 10)
        #expect(viewModel.selectedDay == viewModel.lastDay)
        #expect(!viewModel.canGoForward)

        viewModel.selectedDay = viewModel.firstDay.adding(days: -3)
        #expect(viewModel.selectedDay == viewModel.firstDay)
    }

    @Test func copiesADayToTheFollowingDays() {
        let viewModel = makeViewModel()
        viewModel.editingDay.isha.hasIqamah = true
        viewModel.copyDayCount = 3

        viewModel.copyToFollowingDays()

        #expect(viewModel.editedDayCount == 4)
        viewModel.goToNextDay()
        #expect(viewModel.selectedDayStatus == .edited)
        #expect(viewModel.editingDay.isha.hasIqamah)
    }

    @Test func copyStopsAtTheEndOfTheWindow() {
        let viewModel = makeViewModel()
        viewModel.selectedDay = viewModel.lastDay.adding(days: -1)
        viewModel.editingDay.isha.hasIqamah = true
        viewModel.copyDayCount = 10

        viewModel.copyToFollowingDays()

        #expect(viewModel.editedDayCount == 2)
    }

    @Test func publishesEditedDaysAsManual() async throws {
        let repository = MockMasjidRepository(masjids: [Fixtures.masjid()], adminUID: "admin-1")
        let viewModel = makeViewModel(repository: repository)
        viewModel.editingDay.fajr.hasIqamah = true
        viewModel.copyDayCount = 1
        viewModel.copyToFollowingDays()

        await viewModel.publish()

        let stored = try await repository.schedule(masjidID: "m1", from: viewModel.firstDay, through: viewModel.lastDay)
        #expect(stored.map(\.day.key) == ["2026-10-21", "2026-10-22"])
        #expect(stored.allSatisfy { $0.source == .manual && $0.fajr.iqamah != nil })
        #expect(await repository.publishCallCount == 1)
        #expect(viewModel.editedDayCount == 0)
        #expect(viewModel.selectedDayStatus == .published)
        if case .loaded(let count) = viewModel.publishState {
            #expect(count == 2)
        } else {
            Issue.record("Expected a publish result")
        }
    }

    @Test func dayWithProblemsBlocksPublishing() {
        let viewModel = makeViewModel()

        viewModel.editingDay.dhuhr.adhan = Fixtures.time("05:00")

        #expect(!viewModel.issues.isEmpty)
        #expect(viewModel.daysWithIssues == 1)
        #expect(!viewModel.canPublish)
    }

    @Test func publishedTimesBecomeTheStartingPoint() async throws {
        let repository = MockMasjidRepository(masjids: [Fixtures.masjid()], adminUID: "admin-1")
        try await repository.publish([Fixtures.times(on: "2026-10-21", fajr: "06:00", fajrIqamah: "06:20", source: .manual)],
                                     masjidID: "m1")
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        #expect(viewModel.selectedDayStatus == .published)
        #expect(viewModel.editingDay.fajr.adhan == Fixtures.time("06:00"))
        #expect(viewModel.editingDay.fajr.prayerTime.iqamah == Fixtures.time("06:20"))
        #expect(viewModel.editedDayCount == 0)
    }

    @Test func failedPublishKeepsTheEdits() async {
        let repository = MockMasjidRepository()
        await repository.failNextCall(with: .network)
        let viewModel = makeViewModel(repository: repository)
        viewModel.editingDay.fajr.hasIqamah = true

        await viewModel.publish()

        #expect(viewModel.publishState.error as? RepositoryError == .network)
        #expect(viewModel.editedDayCount == 1)
        #expect(viewModel.canPublish)
    }

    private func makeViewModel(repository: MockMasjidRepository = MockMasjidRepository()) -> ScheduleEditorViewModel {
        ScheduleEditorViewModel(
            masjid: Fixtures.masjid(),
            repository: repository,
            calculator: MockPrayerTimeCalculator(result: .success(Fixtures.times(on: "2026-10-21"))),
            now: now
        )
    }
}

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
