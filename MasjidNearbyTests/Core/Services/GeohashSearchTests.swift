import Foundation
import Testing
@testable import MasjidNearby

struct GeohashSearchTests {
    @Test func boundsMatchTheReferenceCell() throws {
        // Wikipedia's worked example: ezs42 spans 42.583–42.627 N, 5.625–5.581 W.
        let cell = try #require(Geohash.bounds(of: "ezs42"))
        #expect(abs(cell.latitude.lowerBound - 42.5830078125) < 1e-9)
        #expect(abs(cell.latitude.upperBound - 42.626953125) < 1e-9)
        #expect(abs(cell.longitude.lowerBound - -5.625) < 1e-9)
        #expect(abs(cell.longitude.upperBound - -5.5810546875) < 1e-9)
        #expect(Geohash.bounds(of: "ab!") == nil)
    }

    @Test func neighborsMatchTheReferenceSet() {
        // The standard example used by geohash libraries.
        #expect(Set(Geohash.neighbors(of: "dqcjq"))
                == ["dqcjj", "dqcjn", "dqcjp", "dqcjm", "dqcjr", "dqcjt", "dqcjw", "dqcjx"])
    }

    @Test func neighborsWrapAcrossTheAntimeridian() {
        let east = Geohash.encode(Coordinates(latitude: 0.5, longitude: 179.9), precision: 4)
        let west = Geohash.encode(Coordinates(latitude: 0.5, longitude: -179.9), precision: 4)
        #expect(Geohash.neighbors(of: east).contains(west))
    }

    @Test func precisionShrinksAsTheRadiusGrows() {
        #expect(Geohash.precision(forRadiusMeters: 5_000, latitude: 37.3) == 4)
        #expect(Geohash.precision(forRadiusMeters: 25_000, latitude: 37.3) == 3)
        #expect(Geohash.precision(forRadiusMeters: 500, latitude: 37.3) >= 5)
    }

    @Test func coveringPrefixesIncludeEveryPointInTheRadius() {
        let center = Fixtures.sanJose
        let radius = 25_000.0
        let prefixes = Geohash.coveringPrefixes(around: center, radiusMeters: radius)
        let precision = prefixes[0].count
        let metersPerDegree = 111_320.0

        for bearing in stride(from: 0.0, to: 360.0, by: 15.0) {
            let radians = bearing * .pi / 180
            let point = Coordinates(
                latitude: center.latitude + cos(radians) * radius * 0.99 / metersPerDegree,
                longitude: center.longitude + sin(radians) * radius * 0.99
                    / (metersPerDegree * cos(center.latitude * .pi / 180))
            )
            #expect(prefixes.contains(Geohash.encode(point, precision: precision)), "bearing \(bearing)")
        }
    }

    @Test func distanceMatchesKnownValue() {
        let sanFrancisco = Coordinates(latitude: 37.7749, longitude: -122.4194)
        #expect(abs(Fixtures.sanJose.distance(to: sanFrancisco) - 67_570) < 500)
        #expect(Fixtures.sanJose.distance(to: Fixtures.sanJose) == 0)
    }
}
