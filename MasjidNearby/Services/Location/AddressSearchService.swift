import Foundation

/// Turns a typed address into map coordinates. Implementations throw `RepositoryError`.
protocol AddressSearchService: Sendable {
    /// The best match for `address`, or nil when nothing matches.
    func coordinates(for address: String) async throws -> Coordinates?
}

/// Returns canned results. For tests, and for running without network access.
struct MockAddressSearchService: AddressSearchService {
    var results: [String: Coordinates] = [:]
    var error: RepositoryError?

    func coordinates(for address: String) async throws -> Coordinates? {
        if let error { throw error }
        return results[address]
    }
}
