import Foundation
import Testing
@testable import MasjidNearby

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
