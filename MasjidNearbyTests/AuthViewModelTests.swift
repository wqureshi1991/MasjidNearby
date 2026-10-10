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

@MainActor
struct SignUpViewModelTests {
    @Test func freshFormShowsNoValidationMessage() {
        let viewModel = SignUpViewModel(role: .user, authService: MockAuthService())
        #expect(viewModel.validationMessage == nil)
        #expect(!viewModel.canSubmit)
    }

    @Test func reportsTheFirstProblem() {
        let viewModel = SignUpViewModel(role: .user, authService: MockAuthService())

        viewModel.email = "bad"
        #expect(viewModel.validationMessage == AuthError.invalidEmail.errorDescription)

        viewModel.email = "a@example.com"
        viewModel.password = "123"
        #expect(viewModel.validationMessage == AuthError.weakPassword.errorDescription)

        viewModel.password = "123456"
        viewModel.confirmPassword = "1234567"
        #expect(viewModel.validationMessage == "Passwords don't match.")
        #expect(!viewModel.canSubmit)

        viewModel.confirmPassword = "123456"
        #expect(viewModel.validationMessage == nil)
        #expect(viewModel.canSubmit)
    }

    @Test func signUpCreatesAnAccountWithTheScreensRole() async {
        let auth = MockAuthService()
        let viewModel = SignUpViewModel(role: .masjidAdmin, authService: auth)
        viewModel.email = "imam@example.com"
        viewModel.password = "secret1"
        viewModel.confirmPassword = "secret1"

        await viewModel.signUp()

        #expect(viewModel.state.isLoaded)
        guard case .signedIn(let session) = await auth.currentState() else {
            Issue.record("Expected to be signed in")
            return
        }
        #expect(session.role == .masjidAdmin)
    }

    @Test func serviceErrorIsShown() async {
        let auth = MockAuthService()
        await auth.failNextCall(with: .emailAlreadyInUse)
        let viewModel = SignUpViewModel(role: .user, authService: auth)
        viewModel.email = "a@example.com"
        viewModel.password = "secret1"
        viewModel.confirmPassword = "secret1"

        await viewModel.signUp()

        #expect(viewModel.state.error as? AuthError == .emailAlreadyInUse)
    }
}

@MainActor
struct PasswordResetViewModelTests {
    @Test func sendsTheResetEmail() async {
        let auth = MockAuthService()
        let viewModel = PasswordResetViewModel(email: "a@example.com", authService: auth, onDone: {})

        await viewModel.sendReset()

        #expect(viewModel.state.isLoaded)
        #expect(await auth.passwordResetEmails == ["a@example.com"])
    }

    @Test func showsServiceErrors() async {
        let auth = MockAuthService()
        await auth.failNextCall(with: .network)
        let viewModel = PasswordResetViewModel(email: "a@example.com", authService: auth, onDone: {})

        await viewModel.sendReset()

        #expect(viewModel.state.error as? AuthError == .network)
    }

    @Test func invalidEmailIsNotSent() async {
        let auth = MockAuthService()
        let viewModel = PasswordResetViewModel(email: "nope", authService: auth, onDone: {})

        await viewModel.sendReset()

        #expect(!viewModel.canSubmit)
        #expect(await auth.passwordResetEmails.isEmpty)
    }

    @Test func doneCallsBack() {
        var finished = false
        let viewModel = PasswordResetViewModel(email: "", authService: MockAuthService(), onDone: { finished = true })

        viewModel.done()

        #expect(finished)
    }
}

@MainActor
struct WelcomeViewModelTests {
    @Test func guestSignsInAsAUser() async {
        let auth = MockAuthService()
        let viewModel = WelcomeViewModel(authService: auth, onSignIn: { _ in })

        await viewModel.continueAsGuest()

        #expect(viewModel.guestState.isLoaded)
        #expect(await auth.currentState() == .signedIn(AuthSession(userID: "mock-guest", role: .user, isGuest: true)))
    }

    @Test func guestFailureIsShown() async {
        let auth = MockAuthService()
        await auth.failNextCall(with: .network)
        let viewModel = WelcomeViewModel(authService: auth, onSignIn: { _ in })

        await viewModel.continueAsGuest()

        #expect(viewModel.guestState.error as? AuthError == .network)
    }

    @Test func signInForwardsTheRole() {
        var selected: UserRole?
        let viewModel = WelcomeViewModel(authService: MockAuthService(), onSignIn: { selected = $0 })

        viewModel.signIn(as: .masjidAdmin)

        #expect(selected == .masjidAdmin)
    }
}
