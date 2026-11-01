import Foundation

enum AuthState: Sendable, Equatable {
    case signedOut
    case signedIn(AuthSession)
}
