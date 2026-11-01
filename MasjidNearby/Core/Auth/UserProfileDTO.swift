import Foundation

/// Shape of a `users/{uid}` Firestore document. Pure Swift, so it is testable without Firebase.
struct UserProfileDTO: Equatable {
    static let roleKey = "role"

    let role: UserRole

    init(role: UserRole) {
        self.role = role
    }

    /// Throws `AuthError.profileMissing` when the document has no valid role.
    init(data: [String: Any]) throws {
        guard let rawRole = data[Self.roleKey] as? String,
              let role = UserRole(rawValue: rawRole)
        else { throw AuthError.profileMissing }
        self.role = role
    }

    var data: [String: Any] {
        [Self.roleKey: role.rawValue]
    }
}
