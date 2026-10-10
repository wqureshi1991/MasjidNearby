import Observation

/// Navigation before sign-in. Finishing sign-in needs no route here:
/// the auth state change makes `AppCoordinator` swap the whole flow.
@MainActor
@Observable
final class OnboardingCoordinator {
    enum Route: Hashable {
        case signIn(UserRole)
        case signUp(UserRole)
        case resetPassword(email: String)
    }

    var path: [Route] = []

    private let authService: any AuthService

    init(authService: any AuthService) {
        self.authService = authService
    }

    func showSignIn(as role: UserRole) {
        path.append(.signIn(role))
    }

    func showSignUp(as role: UserRole) {
        path.append(.signUp(role))
    }

    func showPasswordReset(email: String) {
        path.append(.resetPassword(email: email))
    }

    func goBack() {
        _ = path.popLast()
    }

    // MARK: - ViewModel factories

    func makeWelcomeViewModel() -> WelcomeViewModel {
        WelcomeViewModel(authService: authService, onSignIn: { [weak self] role in
            self?.showSignIn(as: role)
        })
    }

    func makeSignInViewModel(role: UserRole) -> SignInViewModel {
        SignInViewModel(
            role: role,
            authService: authService,
            onCreateAccount: { [weak self] in self?.showSignUp(as: role) },
            onForgotPassword: { [weak self] email in self?.showPasswordReset(email: email) }
        )
    }

    func makeSignUpViewModel(role: UserRole) -> SignUpViewModel {
        SignUpViewModel(role: role, authService: authService)
    }

    func makePasswordResetViewModel(email: String) -> PasswordResetViewModel {
        PasswordResetViewModel(email: email, authService: authService, onDone: { [weak self] in
            self?.goBack()
        })
    }
}
