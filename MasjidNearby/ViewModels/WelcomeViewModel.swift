import Foundation
import Observation

@MainActor
@Observable
final class WelcomeViewModel {
    private(set) var guestState: LoadState<Void> = .idle

    private let authService: any AuthService
    private let onSignIn: @MainActor (UserRole) -> Void

    init(authService: any AuthService, onSignIn: @escaping @MainActor (UserRole) -> Void) {
        self.authService = authService
        self.onSignIn = onSignIn
    }

    func signIn(as role: UserRole) {
        onSignIn(role)
    }

    func continueAsGuest() async {
        guard !guestState.isLoading else { return }
        guestState = .loading
        do {
            try await authService.continueAsGuest()
            guestState = .loaded(())
        } catch {
            guestState = .failed(error)
        }
    }
}
