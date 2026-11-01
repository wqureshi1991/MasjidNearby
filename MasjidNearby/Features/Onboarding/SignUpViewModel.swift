import Foundation
import Observation

@MainActor
@Observable
final class SignUpViewModel {
    let role: UserRole
    var email = ""
    var password = ""
    var confirmPassword = ""
    private(set) var state: LoadState<Void> = .idle

    private let authService: any AuthService

    init(role: UserRole, authService: any AuthService) {
        self.role = role
        self.authService = authService
    }

    var title: String {
        switch role {
        case .user: "Create Account"
        case .masjidAdmin: "Register Your Masjid"
        }
    }

    /// The first problem with the form, or nil when it can be submitted.
    /// Empty fields are not reported, so a fresh form shows no errors.
    var validationMessage: String? {
        if !email.isEmpty && !CredentialRules.isPlausibleEmail(email) {
            return AuthError.invalidEmail.errorDescription
        }
        if !password.isEmpty && !CredentialRules.isAcceptablePassword(password) {
            return AuthError.weakPassword.errorDescription
        }
        if !confirmPassword.isEmpty && confirmPassword != password {
            return "Passwords don't match."
        }
        return nil
    }

    var canSubmit: Bool {
        CredentialRules.isPlausibleEmail(email)
            && CredentialRules.isAcceptablePassword(password)
            && confirmPassword == password
            && !state.isLoading
    }

    func signUp() async {
        guard canSubmit else { return }
        state = .loading
        do {
            try await authService.signUp(email: email, password: password, role: role)
            state = .loaded(())
        } catch {
            state = .failed(error)
        }
    }
}
