import Foundation

protocol AuthService: Sendable {
    /// Emits the current state immediately, then every change.
    func authStates() async -> AsyncStream<AuthState>
    func signOut() async throws
}
