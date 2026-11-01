import FirebaseAuth
import Foundation

/// Maps FirebaseAuth errors onto `AuthError`. Works on the error's domain and code,
/// so tests can exercise it with plain `NSError`s.
enum AuthErrorMapper {
    static func map(_ error: any Error) -> AuthError {
        if let authError = error as? AuthError {
            return authError
        }
        let nsError = error as NSError
        guard nsError.domain == AuthErrors.domain,
              let code = AuthErrorCode(rawValue: nsError.code)
        else {
            return .unknown(nsError.localizedDescription)
        }
        switch code {
        case .invalidEmail:
            return .invalidEmail
        case .wrongPassword, .invalidCredential, .userNotFound:
            return .wrongCredentials
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .weakPassword:
            return .weakPassword
        case .userDisabled:
            return .accountDisabled
        case .tooManyRequests:
            return .tooManyAttempts
        case .networkError:
            return .network
        default:
            return .unknown(nsError.localizedDescription)
        }
    }
}
