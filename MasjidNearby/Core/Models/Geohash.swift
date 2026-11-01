import Foundation

/// Geohash encoding, stored on each masjid so Firestore can find nearby masjids
/// with prefix range queries (Phase 5).
enum Geohash {
    private static let alphabet = Array("0123456789bcdefghjkmnpqrstuvwxyz")

    /// Precision 9 is a cell of roughly 5 m × 5 m.
    static func encode(_ coordinates: Coordinates, precision: Int = 9) -> String {
        let length = min(max(precision, 1), 12)
        var latitudeRange = (min: -90.0, max: 90.0)
        var longitudeRange = (min: -180.0, max: 180.0)
        var hash = ""
        var bitIndex = 0
        var characterIndex = 0
        var isLongitudeBit = true

        while hash.count < length {
            if isLongitudeBit {
                let mid = (longitudeRange.min + longitudeRange.max) / 2
                if coordinates.longitude >= mid {
                    characterIndex |= 1 << (4 - bitIndex)
                    longitudeRange.min = mid
                } else {
                    longitudeRange.max = mid
                }
            } else {
                let mid = (latitudeRange.min + latitudeRange.max) / 2
                if coordinates.latitude >= mid {
                    characterIndex |= 1 << (4 - bitIndex)
                    latitudeRange.min = mid
                } else {
                    latitudeRange.max = mid
                }
            }
            isLongitudeBit.toggle()

            if bitIndex < 4 {
                bitIndex += 1
            } else {
                hash.append(alphabet[characterIndex])
                bitIndex = 0
                characterIndex = 0
            }
        }
        return hash
    }

    /// The latitude and longitude ranges a geohash covers, or nil if it has invalid characters.
    static func bounds(of hash: String) -> (latitude: ClosedRange<Double>, longitude: ClosedRange<Double>)? {
        var latitudeRange = (min: -90.0, max: 90.0)
        var longitudeRange = (min: -180.0, max: 180.0)
        var isLongitudeBit = true

        for character in hash {
            guard let index = alphabet.firstIndex(of: character) else { return nil }
            for shift in stride(from: 4, through: 0, by: -1) {
                let bitIsSet = (index >> shift) & 1 == 1
                if isLongitudeBit {
                    let mid = (longitudeRange.min + longitudeRange.max) / 2
                    if bitIsSet { longitudeRange.min = mid } else { longitudeRange.max = mid }
                } else {
                    let mid = (latitudeRange.min + latitudeRange.max) / 2
                    if bitIsSet { latitudeRange.min = mid } else { latitudeRange.max = mid }
                }
                isLongitudeBit.toggle()
            }
        }
        return (latitudeRange.min...latitudeRange.max, longitudeRange.min...longitudeRange.max)
    }

    /// The up-to-8 cells around `hash`, at the same precision. Fewer next to a pole.
    static func neighbors(of hash: String) -> [String] {
        guard let cell = bounds(of: hash) else { return [] }
        let height = cell.latitude.upperBound - cell.latitude.lowerBound
        let width = cell.longitude.upperBound - cell.longitude.lowerBound
        let centerLatitude = (cell.latitude.lowerBound + cell.latitude.upperBound) / 2
        let centerLongitude = (cell.longitude.lowerBound + cell.longitude.upperBound) / 2

        var result: [String] = []
        for latitudeStep in -1...1 {
            for longitudeStep in -1...1 where latitudeStep != 0 || longitudeStep != 0 {
                let latitude = centerLatitude + Double(latitudeStep) * height
                guard (-90.0...90.0).contains(latitude) else { continue }
                let rawLongitude = centerLongitude + Double(longitudeStep) * width
                let longitude = (rawLongitude + 540).truncatingRemainder(dividingBy: 360) - 180
                let neighbor = encode(Coordinates(latitude: latitude, longitude: longitude), precision: hash.count)
                if neighbor != hash && !result.contains(neighbor) {
                    result.append(neighbor)
                }
            }
        }
        return result
    }

    /// The longest precision whose cells are at least `radiusMeters` across at this latitude,
    /// so the cell containing a point plus its neighbours covers every place within the radius.
    static func precision(forRadiusMeters radiusMeters: Double, latitude: Double) -> Int {
        // Width shrinks towards the poles; size cells for the poleward edge of the circle.
        let checkLatitude = min(89, abs(latitude) + radiusMeters / metersPerDegree)
        for precision in stride(from: 9, through: 1, by: -1) {
            let latitudeBits = (5 * precision) / 2
            let longitudeBits = 5 * precision - latitudeBits
            let height = 180 / pow(2, Double(latitudeBits)) * metersPerDegree
            let width = 360 / pow(2, Double(longitudeBits)) * metersPerDegree * cos(checkLatitude * .pi / 180)
            if min(height, width) >= radiusMeters {
                return precision
            }
        }
        return 1
    }

    /// The prefixes to query to find everything within `radiusMeters` of `center`.
    static func coveringPrefixes(around center: Coordinates, radiusMeters: Double) -> [String] {
        let cellPrecision = precision(forRadiusMeters: radiusMeters, latitude: center.latitude)
        let centerHash = encode(center, precision: cellPrecision)
        return [centerHash] + neighbors(of: centerHash)
    }

    private static let metersPerDegree = 111_320.0
}
