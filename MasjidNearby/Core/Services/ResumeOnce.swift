import Foundation

/// Resumes a continuation at most once, so a completion handler and a timeout can race safely.
final class ResumeOnce<Value: Sendable>: @unchecked Sendable {
    // @unchecked: `continuation` is only read and cleared while holding `lock`.
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, any Error>?

    init(_ continuation: CheckedContinuation<Value, any Error>) {
        self.continuation = continuation
    }

    /// Returns true if this call resumed the continuation, false if it was already resumed.
    @discardableResult
    func resume(returning value: Value) -> Bool {
        guard let continuation = take() else { return false }
        continuation.resume(returning: value)
        return true
    }

    @discardableResult
    func resume(throwing error: any Error) -> Bool {
        guard let continuation = take() else { return false }
        continuation.resume(throwing: error)
        return true
    }

    private func take() -> CheckedContinuation<Value, any Error>? {
        lock.lock()
        defer { lock.unlock() }
        let taken = continuation
        continuation = nil
        return taken
    }
}
