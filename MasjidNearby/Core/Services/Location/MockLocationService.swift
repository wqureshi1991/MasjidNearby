import Foundation

/// Returns a fixed location or error. For tests and previews.
struct MockLocationService: LocationService {
    var result: Result<Coordinates, LocationError> = .success(Coordinates(latitude: 37.3349, longitude: -122.0090))

    func currentCoordinates() async throws -> Coordinates {
        try result.get()
    }
}
