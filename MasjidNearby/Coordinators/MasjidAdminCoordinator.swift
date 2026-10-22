import Foundation
import Observation

@MainActor
@Observable
final class MasjidAdminCoordinator {
    enum Route: Hashable {
        case registerMasjid
        case editMasjid(Masjid)
        case schedule(Masjid)
    }

    var path: [Route] = []
    let session: AuthSession
    /// The root screen's ViewModel. Owned here so saved changes can update it.
    let home: AdminHomeViewModel

    private let dependencies: AppDependencies
    private let onSignOut: @MainActor () async -> Void

    init(session: AuthSession, dependencies: AppDependencies, onSignOut: @escaping @MainActor () async -> Void) {
        self.session = session
        self.dependencies = dependencies
        self.onSignOut = onSignOut
        home = AdminHomeViewModel(adminUID: session.userID, repository: dependencies.masjidRepository)
        home.onRegister = { [weak self] in
            self?.path.append(.registerMasjid)
        }
        home.onEditDetails = { [weak self] masjid in
            self?.path.append(.editMasjid(masjid))
        }
        home.onEditSchedule = { [weak self] masjid in
            self?.path.append(.schedule(masjid))
        }
    }

    func signOut() async {
        await onSignOut()
    }

    // MARK: - ViewModel factories

    func makeRegistrationViewModel() -> MasjidFormViewModel {
        makeFormViewModel(mode: .create(adminUID: session.userID))
    }

    func makeEditViewModel(for masjid: Masjid) -> MasjidFormViewModel {
        makeFormViewModel(mode: .edit(masjid))
    }

    func makeScheduleEditorViewModel(for masjid: Masjid) -> ScheduleEditorViewModel {
        ScheduleEditorViewModel(
            masjid: masjid,
            repository: dependencies.masjidRepository,
            calculator: dependencies.prayerTimeCalculator
        )
    }

    // MARK: - Private

    private func makeFormViewModel(mode: MasjidFormViewModel.Mode) -> MasjidFormViewModel {
        MasjidFormViewModel(
            mode: mode,
            repository: dependencies.masjidRepository,
            addressSearch: dependencies.addressSearch,
            onSaved: { [weak self] masjid in
                self?.masjidSaved(masjid)
            }
        )
    }

    private func masjidSaved(_ masjid: Masjid) {
        home.show(masjid)
        path.removeAll()
    }
}
