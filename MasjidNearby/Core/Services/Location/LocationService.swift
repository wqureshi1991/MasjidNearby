import Foundation

/// The device's location, asking permission when needed. Implementations throw `LocationError`.
protocol LocationService: Sendable {
    func currentCoordinates() async throws -> Coordinates
}
