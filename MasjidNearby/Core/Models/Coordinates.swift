import Foundation

struct Coordinates: Sendable, Hashable, Codable {
    let latitude: Double
    let longitude: Double

    var isValid: Bool {
        (-90.0...90.0).contains(latitude) && (-180.0...180.0).contains(longitude)
    }

    /// Great-circle distance in meters (haversine, mean Earth radius).
    func distance(to other: Coordinates) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let deltaLatitude = lat2 - lat1
        let deltaLongitude = (other.longitude - longitude) * .pi / 180
        let a = sin(deltaLatitude / 2) * sin(deltaLatitude / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLongitude / 2) * sin(deltaLongitude / 2)
        return 2 * earthRadius * asin(min(1, sqrt(a)))
    }
}
