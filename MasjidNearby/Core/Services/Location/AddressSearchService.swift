import Foundation

/// Turns a typed address into map coordinates. Implementations throw `RepositoryError`.
protocol AddressSearchService: Sendable {
    /// The best match for `address`, or nil when nothing matches.
    func coordinates(for address: String) async throws -> Coordinates?
}
