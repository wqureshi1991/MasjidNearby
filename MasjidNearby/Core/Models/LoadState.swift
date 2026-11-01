import Foundation

enum LoadState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(any Error)

    var isLoading: Bool {
        if case .loading = self { true } else { false }
    }

    var isLoaded: Bool {
        if case .loaded = self { true } else { false }
    }

    var error: (any Error)? {
        if case .failed(let error) = self { error } else { nil }
    }
}
