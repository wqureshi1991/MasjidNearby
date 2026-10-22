import CoreLocation
import Foundation

/// One location fix from Core Location, asking for When In Use permission the first time.
@MainActor
final class CoreLocationService: LocationService {
    private let manager = CLLocationManager()

    func currentCoordinates() async throws -> Coordinates {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            throw LocationError.denied
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }

        return try await withThrowingTaskGroup(of: Coordinates.self, returning: Coordinates.self) { group in
            group.addTask {
                try await Self.firstFix()
            }
            group.addTask {
                // Give the permission prompt and a cold GPS time, but don't spin forever.
                try await Task.sleep(for: .seconds(20))
                throw LocationError.unavailable
            }
            defer { group.cancelAll() }
            guard let coordinates = try await group.next() else {
                throw LocationError.unavailable
            }
            return coordinates
        }
    }

    private static func firstFix() async throws -> Coordinates {
        for try await update in CLLocationUpdate.liveUpdates() {
            if let coordinate = update.location?.coordinate {
                return Coordinates(latitude: coordinate.latitude, longitude: coordinate.longitude)
            }
            let status = CLLocationManager().authorizationStatus
            if status == .denied || status == .restricted {
                throw LocationError.denied
            }
        }
        throw LocationError.unavailable
    }
}
