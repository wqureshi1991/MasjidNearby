import Foundation

/// Broadcasts auth state to any number of subscribers.
/// A new subscriber gets the latest state first, if there is one.
actor AuthStateHub {
    private(set) var current: AuthState?
    private var continuations: [UUID: AsyncStream<AuthState>.Continuation] = [:]

    init(initial: AuthState? = nil) {
        current = initial
    }

    func stream() -> AsyncStream<AuthState> {
        let (stream, continuation) = AsyncStream.makeStream(of: AuthState.self)
        let id = UUID()
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeContinuation(id) }
        }
        if let current {
            continuation.yield(current)
        }
        return stream
    }

    func send(_ state: AuthState) {
        current = state
        for continuation in continuations.values {
            continuation.yield(state)
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }
}
