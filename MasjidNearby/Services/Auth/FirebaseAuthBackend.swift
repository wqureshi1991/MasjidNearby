import FirebaseAuth
import Foundation

/// The only type that talks to FirebaseAuth.
///
/// FirebaseAuth's `Auth`, `User` and `AuthDataResult` are not `Sendable`, so they never leave
/// this file: each call uses the completion-handler API and hands back plain `Sendable` values.
struct FirebaseAuthBackend: AuthBackend {
    func currentAccount() -> AuthAccount? {
        guard let user = Auth.auth().currentUser else { return nil }
        return AuthAccount(uid: user.uid, isAnonymous: user.isAnonymous)
    }

    func signIn(email: String, password: String) async throws -> AuthAccount {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                continuation.resume(with: Self.account(from: result, error: error))
            }
        }
    }

    func createAccount(email: String, password: String) async throws -> AuthAccount {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                continuation.resume(with: Self.account(from: result, error: error))
            }
        }
    }

    func signInAnonymously() async throws -> AuthAccount {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signInAnonymously { result, error in
                continuation.resume(with: Self.account(from: result, error: error))
            }
        }
    }

    func sendPasswordReset(email: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            Auth.auth().sendPasswordReset(withEmail: email) { error in
                if let error {
                    continuation.resume(throwing: AuthErrorMapper.map(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func signOut() throws {
        do {
            try Auth.auth().signOut()
        } catch {
            throw AuthErrorMapper.map(error)
        }
    }

    func deleteCurrentAccount() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            guard let user = Auth.auth().currentUser else {
                continuation.resume()
                return
            }
            user.delete { error in
                if let error {
                    continuation.resume(throwing: AuthErrorMapper.map(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func account(from result: AuthDataResult?, error: (any Error)?) -> Result<AuthAccount, any Error> {
        if let error {
            return .failure(AuthErrorMapper.map(error))
        }
        guard let user = result?.user else {
            return .failure(AuthError.unknown("Sign-in returned no user."))
        }
        return .success(AuthAccount(uid: user.uid, isAnonymous: user.isAnonymous))
    }
}

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
