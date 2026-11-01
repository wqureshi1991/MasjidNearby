import Foundation
import Testing
@testable import MasjidNearby

struct GeohashTests {
    @Test func matchesPublishedReferenceValues() {
        // Reference values from the geohash.org / Wikipedia examples.
        #expect(Geohash.encode(Coordinates(latitude: 57.64911, longitude: 10.40744), precision: 11) == "u4pruydqqvj")
        #expect(Geohash.encode(Coordinates(latitude: 42.6, longitude: -5.6), precision: 5) == "ezs42")
    }

    @Test func encodesKnownCities() {
        #expect(Geohash.encode(Fixtures.sanJose) == "9q9k6mjng")
        #expect(Geohash.encode(Coordinates(latitude: -33.8688, longitude: 151.2093), precision: 6) == "r3gx2f")
    }

    @Test func nearbyPointsShareAPrefix() {
        let a = Geohash.encode(Fixtures.sanJose, precision: 6)
        let b = Geohash.encode(Coordinates(latitude: 37.3390, longitude: -121.8870), precision: 6)
        #expect(a.prefix(5) == b.prefix(5))
    }

    @Test func clampsPrecision() {
        #expect(Geohash.encode(Fixtures.sanJose, precision: 0).count == 1)
        #expect(Geohash.encode(Fixtures.sanJose, precision: 40).count == 12)
    }
}
