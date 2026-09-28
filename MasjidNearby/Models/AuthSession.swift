import Foundation

enum UserRole: String, Sendable, Codable, Hashable {
    case user
    case masjidAdmin
}

struct AuthSession: Sendable, Hashable {
    let userID: String
    let role: UserRole
}

enum AuthState: Sendable, Equatable {
    case signedOut
    case signedIn(AuthSession)
}
