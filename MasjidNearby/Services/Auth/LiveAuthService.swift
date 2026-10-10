import Foundation
import OSLog

/// Auth logic: combines the identity backend with the role stored in each user's profile.
/// Holds no Firebase types, so it is fully testable with fakes.
actor LiveAuthService: AuthService {
    private let backend: any AuthBackend
    private let profiles: any UserProfileStore
    private let hub = AuthStateHub()
    private var hasRestoredSession = false
    private let logger = Logger(subsystem: "com.waqarqureshi.MasjidNearby", category: "Auth")

    init(backend: any AuthBackend, profiles: any UserProfileStore) {
        self.backend = backend
        self.profiles = profiles
    }

    func authStates() async -> AsyncStream<AuthState> {
        let stream = await hub.stream()
        if !hasRestoredSession {
            hasRestoredSession = true
            let restored = await restoredState()
            await hub.send(restored)
        }
        return stream
    }

    func signIn(email: String, password: String) async throws {
        let account = try await backend.signIn(email: CredentialRules.normalizedEmail(email), password: password)
        let storedRole: UserRole?
        do {
            storedRole = try await profiles.role(for: account.uid)
        } catch {
            await discardSession()
            throw error
        }
        guard let role = storedRole else {
            await discardSession()
            throw AuthError.profileMissing
        }
        await hub.send(.signedIn(AuthSession(userID: account.uid, role: role)))
    }

    func signUp(email: String, password: String, role: UserRole) async throws {
        let account = try await backend.createAccount(email: CredentialRules.normalizedEmail(email), password: password)
        do {
            try await profiles.createProfile(uid: account.uid, role: role)
        } catch {
            // Roll back so the same email can sign up again.
            await deleteAccountAfterFailedSignUp()
            throw error
        }
        await hub.send(.signedIn(AuthSession(userID: account.uid, role: role)))
    }

    func continueAsGuest() async throws {
        let account = try await backend.signInAnonymously()
        await hub.send(.signedIn(AuthSession(userID: account.uid, role: .user, isGuest: true)))
    }

    func sendPasswordReset(email: String) async throws {
        try await backend.sendPasswordReset(email: CredentialRules.normalizedEmail(email))
    }

    func signOut() async throws {
        try await backend.signOut()
        await hub.send(.signedOut)
    }

    // MARK: - Private

    private func restoredState() async -> AuthState {
        guard let account = await backend.currentAccount() else { return .signedOut }
        if account.isAnonymous {
            return .signedIn(AuthSession(userID: account.uid, role: .user, isGuest: true))
        }
        do {
            guard let role = try await profiles.role(for: account.uid) else {
                logger.error("Signed-in account has no profile; signing out.")
                await discardSession()
                return .signedOut
            }
            return .signedIn(AuthSession(userID: account.uid, role: role))
        } catch {
            // Keep the session: the next launch or sign-in can retry once the network is back.
            logger.error("Could not load profile on launch: \(error.localizedDescription, privacy: .public)")
            return .signedOut
        }
    }

    private func discardSession() async {
        do {
            try await backend.signOut()
        } catch {
            logger.error("Sign out after failed sign-in failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func deleteAccountAfterFailedSignUp() async {
        do {
            try await backend.deleteCurrentAccount()
        } catch {
            logger.error("Rollback of failed sign-up failed: \(error.localizedDescription, privacy: .public)")
            await discardSession()
        }
    }
}
