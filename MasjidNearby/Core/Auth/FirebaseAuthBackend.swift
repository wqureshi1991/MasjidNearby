import FirebaseAuth
import Foundation

/// The only type that talks to FirebaseAuth.
///
/// FirebaseAuth's `Auth`, `User` and `AuthDataResult` are not `Sendable`, so they never leave
/// this file: each call hands back plain `Sendable` values.
struct FirebaseAuthBackend: AuthBackend {
    func currentAccount() -> AuthAccount? {
        Auth.auth().currentUser.map(Self.account(for:))
    }

    func signIn(email: String, password: String) async throws -> AuthAccount {
        do {
            return Self.account(for: try await Auth.auth().signIn(withEmail: email, password: password).user)
        } catch {
            throw AuthErrorMapper.map(error)
        }
    }

    func createAccount(email: String, password: String) async throws -> AuthAccount {
        do {
            return Self.account(for: try await Auth.auth().createUser(withEmail: email, password: password).user)
        } catch {
            throw AuthErrorMapper.map(error)
        }
    }

    func signInAnonymously() async throws -> AuthAccount {
        do {
            return Self.account(for: try await Auth.auth().signInAnonymously().user)
        } catch {
            throw AuthErrorMapper.map(error)
        }
    }

    func sendPasswordReset(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            throw AuthErrorMapper.map(error)
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
        guard let user = Auth.auth().currentUser else { return }
        do {
            try await user.delete()
        } catch {
            throw AuthErrorMapper.map(error)
        }
    }

    private static func account(for user: User) -> AuthAccount {
        AuthAccount(uid: user.uid, isAnonymous: user.isAnonymous)
    }
}
