import Foundation

enum LocationError: Error, Sendable, Equatable, LocalizedError {
    case denied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .denied:
            "Location access is off. Search for a city or address instead, or allow location in Settings."
        case .unavailable:
            "Couldn't find your location. Try again, or search for a city or address."
        }
    }
}

/// The device's location, asking permission when needed. Implementations throw `LocationError`.
protocol LocationService: Sendable {
    func currentCoordinates() async throws -> Coordinates
}

/// Returns a fixed location or error. For tests and previews.
struct MockLocationService: LocationService {
    var result: Result<Coordinates, LocationError> = .success(Coordinates(latitude: 37.3349, longitude: -122.0090))

    func currentCoordinates() async throws -> Coordinates {
        try result.get()
    }
}
