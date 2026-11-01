import Foundation
import Testing
@testable import MasjidNearby

@MainActor
struct SignInViewModelTests {
    @Test func cannotSubmitUntilEmailAndPasswordLookValid() {
        let viewModel = makeViewModel(auth: MockAuthService())
        #expect(!viewModel.canSubmit)

        viewModel.email = "not-an-email"
        viewModel.password = "secret1"
        #expect(!viewModel.canSubmit)

        viewModel.email = "a@example.com"
        #expect(viewModel.canSubmit)
    }

    @Test func successfulSignInSignsTheServiceIn() async throws {
        let auth = MockAuthService()
        try await auth.signUp(email: "a@example.com", password: "secret1", role: .masjidAdmin)
        try await auth.signOut()
        let viewModel = makeViewModel(auth: auth)
        viewModel.email = "a@example.com"
        viewModel.password = "secret1"

        await viewModel.signIn()

        #expect(viewModel.state.isLoaded)
        guard case .signedIn(let session) = await auth.currentState() else {
            Issue.record("Expected to be signed in")
            return
        }
        #expect(session.role == .masjidAdmin)
    }

    @Test func failedSignInShowsTheError() async {
        let viewModel = makeViewModel(auth: MockAuthService())
        viewModel.email = "a@example.com"
        viewModel.password = "wrong1"

        await viewModel.signIn()

        #expect(viewModel.state.error as? AuthError == .wrongCredentials)
        #expect(viewModel.canSubmit)
    }

    @Test func forgotPasswordPassesTheTypedEmail() {
        var forwarded: String?
        let viewModel = SignInViewModel(role: .user, authService: MockAuthService(),
                                        onCreateAccount: {}, onForgotPassword: { forwarded = $0 })
        viewModel.email = " a@example.com "

        viewModel.forgotPassword()

        #expect(forwarded == "a@example.com")
    }

    @Test func titleReflectsTheRole() {
        #expect(makeViewModel(auth: MockAuthService(), role: .user).title == "Sign In")
        #expect(makeViewModel(auth: MockAuthService(), role: .masjidAdmin).title == "Masjid Sign In")
    }

    private func makeViewModel(auth: MockAuthService, role: UserRole = .user) -> SignInViewModel {
        SignInViewModel(role: role, authService: auth, onCreateAccount: {}, onForgotPassword: { _ in })
    }
}
