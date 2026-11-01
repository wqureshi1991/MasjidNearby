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
