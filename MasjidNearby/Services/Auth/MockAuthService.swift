import Foundation

/// In-memory auth. Used by tests, and by the app when `GoogleService-Info.plist` is missing.
actor MockAuthService: AuthService {
    private struct Account {
        let uid: String
        let password: String
        let role: UserRole
    }

    private let hub: AuthStateHub
    /// Keyed by normalized, lowercased email.
    private var accounts: [String: Account] = [:]
    private var nextError: AuthError?
    private(set) var passwordResetEmails: [String] = []

    init(initialState: AuthState = .signedOut) {
        hub = AuthStateHub(initial: initialState)
    }

    func authStates() async -> AsyncStream<AuthState> {
        await hub.stream()
    }

    func signIn(email: String, password: String) async throws {
        try throwInjectedError()
        guard let account = accounts[Self.key(email)], account.password == password else {
            throw AuthError.wrongCredentials
        }
        await hub.send(.signedIn(AuthSession(userID: account.uid, role: account.role)))
    }

    func signUp(email: String, password: String, role: UserRole) async throws {
        try throwInjectedError()
        let key = Self.key(email)
        guard CredentialRules.isPlausibleEmail(key) else { throw AuthError.invalidEmail }
        guard accounts[key] == nil else { throw AuthError.emailAlreadyInUse }
        guard CredentialRules.isAcceptablePassword(password) else { throw AuthError.weakPassword }
        let account = Account(uid: "mock-\(accounts.count + 1)", password: password, role: role)
        accounts[key] = account
        await hub.send(.signedIn(AuthSession(userID: account.uid, role: role)))
    }

    func continueAsGuest() async throws {
        try throwInjectedError()
        await hub.send(.signedIn(AuthSession(userID: "mock-guest", role: .user, isGuest: true)))
    }

    func sendPasswordReset(email: String) async throws {
        try throwInjectedError()
        passwordResetEmails.append(Self.key(email))
    }

    func signOut() async throws {
        try throwInjectedError()
        await hub.send(.signedOut)
    }

    // MARK: - Test hooks

    /// Signs in with `role` without credentials.
    func signIn(as role: UserRole) async {
        await hub.send(.signedIn(AuthSession(userID: "mock-\(role.rawValue)", role: role)))
    }

    /// The next call to any `AuthService` method throws `error`.
    func failNextCall(with error: AuthError) {
        nextError = error
    }

    func currentState() async -> AuthState? {
        await hub.current
    }

    private func throwInjectedError() throws {
        guard let error = nextError else { return }
        nextError = nil
        throw error
    }

    private static func key(_ email: String) -> String {
        CredentialRules.normalizedEmail(email).lowercased()
    }
}
