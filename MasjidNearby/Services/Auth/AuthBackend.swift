import Foundation

struct AuthAccount: Sendable, Equatable {
    let uid: String
    let isAnonymous: Bool
}

/// The identity provider. Firebase Auth in production; fakes in tests.
/// Implementations throw `AuthError`.
protocol AuthBackend: Sendable {
    func currentAccount() async -> AuthAccount?
    func signIn(email: String, password: String) async throws -> AuthAccount
    func createAccount(email: String, password: String) async throws -> AuthAccount
    func signInAnonymously() async throws -> AuthAccount
    func sendPasswordReset(email: String) async throws
    func signOut() async throws
    /// Deletes the signed-in account. Used to roll back a sign-up whose profile could not be written.
    func deleteCurrentAccount() async throws
}

/// Where each account's role is stored: `users/{uid}` in Firestore.
/// Implementations throw `AuthError`.
protocol UserProfileStore: Sendable {
    /// Nil when the account has no profile document.
    func role(for uid: String) async throws -> UserRole?
    func createProfile(uid: String, role: UserRole) async throws
}
