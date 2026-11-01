import Foundation

/// Returns canned results. For tests, and for running without network access.
struct MockAddressSearchService: AddressSearchService {
    var results: [String: Coordinates] = [:]
    var error: RepositoryError?

    func coordinates(for address: String) async throws -> Coordinates? {
        if let error { throw error }
        return results[address]
    }
}
