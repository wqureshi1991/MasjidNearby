import Observation

@MainActor
@Observable
final class MasjidAdminCoordinator {
    enum Route: Hashable {
        case scheduleEditor
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

    func showScheduleEditor() {
        path.append(.scheduleEditor)
    }

    func signOut() async {
        await onSignOut()
    }
}
