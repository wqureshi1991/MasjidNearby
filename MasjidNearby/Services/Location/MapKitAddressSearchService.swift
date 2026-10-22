import Foundation
import MapKit

/// Address search with MapKit. Like the Firebase wrappers, it uses the completion-handler API
/// and hands back only a `Sendable` coordinate.
struct MapKitAddressSearchService: AddressSearchService {
    func coordinates(for address: String) async throws -> Coordinates? {
        let query = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Coordinates?, any Error>) in
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            MKLocalSearch(request: request).start { response, error in
                if let error {
                    if (error as? MKError)?.code == .placemarkNotFound {
                        continuation.resume(returning: nil)
                    } else {
                        continuation.resume(throwing: RepositoryError.unknown(error.localizedDescription))
                    }
                    return
                }
                guard let coordinate = response?.mapItems.first?.placemark.coordinate else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: Coordinates(latitude: coordinate.latitude, longitude: coordinate.longitude))
            }
        }
    }
}
