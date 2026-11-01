import Foundation

/// Everything the app needs from authentication. Methods throw `AuthError`.
protocol AuthService: Sendable {
    /// Emits the current state as soon as it is known, then every change.
    func authStates() async -> AsyncStream<AuthState>
    func signIn(email: String, password: String) async throws
    /// Creates the account and its profile with `role`, then signs in.
    func signUp(email: String, password: String, role: UserRole) async throws
    /// Anonymous sign-in with the `.user` role.
    func continueAsGuest() async throws
    func sendPasswordReset(email: String) async throws
    func signOut() async throws
}
