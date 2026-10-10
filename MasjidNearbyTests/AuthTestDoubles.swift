import Foundation
@testable import MasjidNearby

actor FakeAuthBackend: AuthBackend {
    private struct Credentials {
        let password: String
        let account: AuthAccount
    }

    private var current: AuthAccount?
    private var credentials: [String: Credentials] = [:]
    private var nextError: AuthError?
    private(set) var signOutCount = 0
    private(set) var deletedUIDs: [String] = []
    private(set) var receivedEmails: [String] = []

    init(current: AuthAccount? = nil) {
        self.current = current
    }

    func addAccount(email: String, password: String, uid: String) {
        credentials[email] = Credentials(password: password, account: AuthAccount(uid: uid, isAnonymous: false))
    }

    func failNextCall(with error: AuthError) {
        nextError = error
    }

    func currentAccount() -> AuthAccount? {
        current
    }

    func signIn(email: String, password: String) throws -> AuthAccount {
        receivedEmails.append(email)
        try throwInjectedError()
        guard let stored = credentials[email], stored.password == password else {
            throw AuthError.wrongCredentials
        }
        current = stored.account
        return stored.account
    }

    func createAccount(email: String, password: String) throws -> AuthAccount {
        receivedEmails.append(email)
        try throwInjectedError()
        guard credentials[email] == nil else { throw AuthError.emailAlreadyInUse }
        let account = AuthAccount(uid: "uid-\(credentials.count + 1)", isAnonymous: false)
        credentials[email] = Credentials(password: password, account: account)
        current = account
        return account
    }

    func signInAnonymously() throws -> AuthAccount {
        try throwInjectedError()
        let account = AuthAccount(uid: "anon-1", isAnonymous: true)
        current = account
        return account
    }

    func sendPasswordReset(email: String) throws {
        receivedEmails.append(email)
        try throwInjectedError()
    }

    func signOut() throws {
        try throwInjectedError()
        signOutCount += 1
        current = nil
    }

    func deleteCurrentAccount() throws {
        try throwInjectedError()
        guard let current else { return }
        deletedUIDs.append(current.uid)
        credentials = credentials.filter { $0.value.account != current }
        self.current = nil
    }

    private func throwInjectedError() throws {
        guard let error = nextError else { return }
        nextError = nil
        throw error
    }
}

actor FakeUserProfileStore: UserProfileStore {
    private(set) var roles: [String: UserRole]
    private var readError: AuthError?
    private var writeError: AuthError?

    init(roles: [String: UserRole] = [:]) {
        self.roles = roles
    }

    func failReads(with error: AuthError) {
        readError = error
    }

    func failWrites(with error: AuthError) {
        writeError = error
    }

    func role(for uid: String) throws -> UserRole? {
        if let readError { throw readError }
        return roles[uid]
    }

    func createProfile(uid: String, role: UserRole) throws {
        if let writeError { throw writeError }
        roles[uid] = role
    }
}

/// The service's current state: a fresh subscription is sent the latest state first.
func currentState(of service: any AuthService) async -> AuthState? {
    var iterator = await service.authStates().makeAsyncIterator()
    return await iterator.next()
}
