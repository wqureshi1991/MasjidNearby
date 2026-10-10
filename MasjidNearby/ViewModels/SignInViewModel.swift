import Foundation
import Observation

@MainActor
@Observable
final class SignInViewModel {
    let role: UserRole
    var email = ""
    var password = ""
    private(set) var state: LoadState<Void> = .idle

    private let authService: any AuthService
    private let onCreateAccount: @MainActor () -> Void
    private let onForgotPassword: @MainActor (String) -> Void

    init(role: UserRole,
         authService: any AuthService,
         onCreateAccount: @escaping @MainActor () -> Void,
         onForgotPassword: @escaping @MainActor (String) -> Void) {
        self.role = role
        self.authService = authService
        self.onCreateAccount = onCreateAccount
        self.onForgotPassword = onForgotPassword
    }

    var title: String {
        switch role {
        case .user: "Sign In"
        case .masjidAdmin: "Masjid Sign In"
        }
    }

    var canSubmit: Bool {
        CredentialRules.isPlausibleEmail(email) && !password.isEmpty && !state.isLoading
    }

    func signIn() async {
        guard canSubmit else { return }
        state = .loading
        do {
            try await authService.signIn(email: email, password: password)
            state = .loaded(())
        } catch {
            state = .failed(error)
        }
    }

    func createAccount() {
        onCreateAccount()
    }

    func forgotPassword() {
        onForgotPassword(CredentialRules.normalizedEmail(email))
    }
}
