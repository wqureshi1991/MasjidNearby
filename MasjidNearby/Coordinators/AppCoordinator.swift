import Observation
import OSLog

enum AppFlow {
    case launching
    case onboarding
    case user(UserCoordinator)
    case masjidAdmin(MasjidAdminCoordinator)
}

@MainActor
@Observable
final class AppCoordinator {
    private(set) var flow: AppFlow = .launching

    private let dependencies: AppDependencies
    @ObservationIgnored private var currentSession: AuthSession?
    @ObservationIgnored private var isObservingAuth = false
    private let logger = Logger(subsystem: "com.waqarqureshi.MasjidNearby", category: "AppCoordinator")

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    /// Call from `.task`. Runs until the task is cancelled; re-entrant calls are ignored.
    func start() async {
        guard !isObservingAuth else { return }
        isObservingAuth = true
        defer { isObservingAuth = false }

        let states = await dependencies.authService.authStates()
        for await state in states {
            apply(state)
        }
    }

    func signOut() async {
        do {
            try await dependencies.authService.signOut()
        } catch {
            logger.error("Sign out failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    #if DEBUG
    /// Temporary until Phase 3 adds real sign-in screens.
    func debugSignIn(as role: UserRole) async {
        guard let mock = dependencies.authService as? MockAuthService else { return }
        await mock.signIn(as: role)
    }
    #endif

    private func apply(_ state: AuthState) {
        switch state {
        case .signedOut:
            currentSession = nil
            flow = .onboarding
        case .signedIn(let session):
            guard session != currentSession else { return }
            currentSession = session
            flow = makeFlow(for: session)
        }
    }

    private func makeFlow(for session: AuthSession) -> AppFlow {
        let onSignOut: @MainActor () async -> Void = { [weak self] in
            await self?.signOut()
        }
        switch session.role {
        case .user:
            return .user(UserCoordinator(session: session, dependencies: dependencies, onSignOut: onSignOut))
        case .masjidAdmin:
            return .masjidAdmin(MasjidAdminCoordinator(session: session, dependencies: dependencies, onSignOut: onSignOut))
        }
    }
}
