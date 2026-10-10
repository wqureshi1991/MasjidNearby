import SwiftUI

/// Root of the signed-out flow.
struct OnboardingView: View {
    @Bindable var coordinator: OnboardingCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            WelcomeView(viewModel: coordinator.makeWelcomeViewModel())
                .navigationDestination(for: OnboardingCoordinator.Route.self) { route in
                    switch route {
                    case .signIn(let role):
                        SignInView(viewModel: coordinator.makeSignInViewModel(role: role))
                    case .signUp(let role):
                        SignUpView(viewModel: coordinator.makeSignUpViewModel(role: role))
                    case .resetPassword(let email):
                        PasswordResetView(viewModel: coordinator.makePasswordResetViewModel(email: email))
                    }
                }
        }
    }
}
