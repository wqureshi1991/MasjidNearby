import Observation

@MainActor
@Observable
final class UserCoordinator {
    enum Route: Hashable {
        case masjidDetail(masjidID: String)
    }

    var path: [Route] = []
    let session: AuthSession

    private let dependencies: AppDependencies
    private let onSignOut: @MainActor () async -> Void

    init(session: AuthSession, dependencies: AppDependencies, onSignOut: @escaping @MainActor () async -> Void) {
        self.session = session
        self.dependencies = dependencies
        self.onSignOut = onSignOut
    }

    func showMasjidDetail(masjidID: String) {
        path.append(.masjidDetail(masjidID: masjidID))
    }

    func signOut() async {
        await onSignOut()
    }
}
