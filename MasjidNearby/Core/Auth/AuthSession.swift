import Foundation

struct AuthSession: Sendable, Hashable {
    let userID: String
    let role: UserRole
    /// Signed in anonymously. Always has the `.user` role.
    let isGuest: Bool

    init(userID: String, role: UserRole, isGuest: Bool = false) {
        self.userID = userID
        self.role = role
        self.isGuest = isGuest
    }
}
