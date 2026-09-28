import Foundation

actor MockAuthService: AuthService {
    private var state: AuthState
    private var continuations: [UUID: AsyncStream<AuthState>.Continuation] = [:]

    init(initialState: AuthState = .signedOut) {
        state = initialState
    }

    func authStates() -> AsyncStream<AuthState> {
        let (stream, continuation) = AsyncStream.makeStream(of: AuthState.self)
        let id = UUID()
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeContinuation(id) }
        }
        continuation.yield(state)
        return stream
    }

    func signIn(as role: UserRole) {
        update(.signedIn(AuthSession(userID: "mock-\(role.rawValue)", role: role)))
    }

    func signOut() {
        update(.signedOut)
    }

    private func update(_ newState: AuthState) {
        state = newState
        for continuation in continuations.values {
            continuation.yield(newState)
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }
}
