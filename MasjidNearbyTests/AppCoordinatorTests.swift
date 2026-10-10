import Testing
@testable import MasjidNearby

@MainActor
struct AppCoordinatorTests {
    @Test func signedOutShowsOnboarding() async {
        let coordinator = AppCoordinator(dependencies: AppDependencies(authService: MockAuthService()))
        let task = Task { await coordinator.start() }
        defer { task.cancel() }

        let reached = await waitUntil { if case .onboarding = coordinator.flow { true } else { false } }
        #expect(reached)
    }

    @Test func userSignInShowsUserFlow() async {
        let auth = MockAuthService()
        let coordinator = AppCoordinator(dependencies: AppDependencies(authService: auth))
        let task = Task { await coordinator.start() }
        defer { task.cancel() }

        await auth.signIn(as: .user)

        let reached = await waitUntil { if case .user = coordinator.flow { true } else { false } }
        #expect(reached)
    }

    @Test func guestShowsUserFlow() async throws {
        let auth = MockAuthService()
        let coordinator = AppCoordinator(dependencies: AppDependencies(authService: auth))
        let task = Task { await coordinator.start() }
        defer { task.cancel() }

        try await auth.continueAsGuest()

        let reached = await waitUntil {
            if case .user(let userCoordinator) = coordinator.flow { userCoordinator.session.isGuest } else { false }
        }
        #expect(reached)
    }

    @Test func adminSignOutReturnsToOnboarding() async {
        let auth = MockAuthService(initialState: .signedIn(AuthSession(userID: "a1", role: .masjidAdmin)))
        let coordinator = AppCoordinator(dependencies: AppDependencies(authService: auth))
        let task = Task { await coordinator.start() }
        defer { task.cancel() }

        let showedAdmin = await waitUntil { if case .masjidAdmin = coordinator.flow { true } else { false } }
        #expect(showedAdmin)

        await coordinator.signOut()

        let showedOnboarding = await waitUntil { if case .onboarding = coordinator.flow { true } else { false } }
        #expect(showedOnboarding)
    }

    @Test func onboardingNavigationPushesRoutes() {
        let onboarding = OnboardingCoordinator(authService: MockAuthService())

        onboarding.makeWelcomeViewModel().signIn(as: .masjidAdmin)
        #expect(onboarding.path == [.signIn(.masjidAdmin)])

        onboarding.makeSignInViewModel(role: .masjidAdmin).createAccount()
        #expect(onboarding.path == [.signIn(.masjidAdmin), .signUp(.masjidAdmin)])

        onboarding.goBack()
        let signIn = onboarding.makeSignInViewModel(role: .masjidAdmin)
        signIn.email = "imam@example.com"
        signIn.forgotPassword()
        #expect(onboarding.path == [.signIn(.masjidAdmin), .resetPassword(email: "imam@example.com")])

        onboarding.makePasswordResetViewModel(email: "imam@example.com").done()
        #expect(onboarding.path == [.signIn(.masjidAdmin)])
    }

    /// Polls `condition` on the main actor until it passes or the timeout elapses.
    private func waitUntil(timeout: Duration = .seconds(1), _ condition: () -> Bool) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if condition() { return true }
            do {
                try await Task.sleep(for: .milliseconds(10))
            } catch {
                return condition()
            }
        }
        return condition()
    }
}
