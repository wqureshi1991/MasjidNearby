import Foundation
import Observation

@MainActor
@Observable
final class PasswordResetViewModel {
    var email: String
    private(set) var state: LoadState<Void> = .idle

    private let authService: any AuthService
    private let onDone: @MainActor () -> Void

    init(email: String, authService: any AuthService, onDone: @escaping @MainActor () -> Void) {
        self.email = email
        self.authService = authService
        self.onDone = onDone
    }

    var canSubmit: Bool {
        CredentialRules.isPlausibleEmail(email) && !state.isLoading
    }

    func sendReset() async {
        guard canSubmit else { return }
        state = .loading
        do {
            try await authService.sendPasswordReset(email: email)
            state = .loaded(())
        } catch {
            state = .failed(error)
        }
    }

    func done() {
        onDone()
    }
}
