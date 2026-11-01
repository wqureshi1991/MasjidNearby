import Foundation

/// Where each account's role is stored: `users/{uid}` in Firestore.
/// Implementations throw `AuthError`.
protocol UserProfileStore: Sendable {
    /// Nil when the account has no profile document.
    func role(for uid: String) async throws -> UserRole?
    func createProfile(uid: String, role: UserRole) async throws
}
