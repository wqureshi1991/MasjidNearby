import Foundation

/// Collects values passed to a `@Sendable` callback, for checking in tests.
final class Recorder<Value: Sendable>: @unchecked Sendable {
    // @unchecked: `storage` is only touched while holding `lock`.
    private let lock = NSLock()
    private var storage: [Value] = []

    var values: [Value] {
        lock.withLock { storage }
    }

    func record(_ value: Value) {
        lock.withLock { storage.append(value) }
    }
}
