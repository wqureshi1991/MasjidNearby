import Foundation
import Testing
@testable import MasjidNearby

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
