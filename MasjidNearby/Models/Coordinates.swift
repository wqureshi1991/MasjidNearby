import Foundation

struct Coordinates: Sendable, Hashable, Codable {
    let latitude: Double
    let longitude: Double

    var isValid: Bool {
        (-90.0...90.0).contains(latitude) && (-180.0...180.0).contains(longitude)
    }
}
