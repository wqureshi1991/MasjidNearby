import SwiftUI

/// Leaves the user flow: "Exit" for guests, "Sign Out" for accounts.
struct SignOutButton: View {
    let coordinator: UserCoordinator

    var body: some View {
        Button(coordinator.session.isGuest ? "Exit" : "Sign Out") {
            Task { await coordinator.signOut() }
        }
    }
}
