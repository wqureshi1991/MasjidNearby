import Foundation
import Testing
@testable import MasjidNearby

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
