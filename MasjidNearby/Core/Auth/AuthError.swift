import Foundation

/// Every auth failure the app can show. Backends map their own errors into these.
enum AuthError: Error, Sendable, Equatable, LocalizedError {
    case invalidEmail
    /// Wrong password or no such account. Deliberately not told apart.
    case wrongCredentials
    case emailAlreadyInUse
    case weakPassword
    case accountDisabled
    case tooManyAttempts
    case network
    /// Signed in, but the account has no usable profile document.
    case profileMissing
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            "That email address doesn't look right."
        case .wrongCredentials:
            "Email or password is incorrect."
        case .emailAlreadyInUse:
            "An account with this email already exists. Try signing in."
        case .weakPassword:
            "Password must be at least \(CredentialRules.minimumPasswordLength) characters."
        case .accountDisabled:
            "This account has been disabled."
        case .tooManyAttempts:
            "Too many attempts. Wait a moment and try again."
        case .network:
            "Can't reach the server. Check your connection and try again."
        case .profileMissing:
            "This account isn't fully set up. Please create it again or contact support."
        case .unknown(let message):
            message
        }
    }
}
