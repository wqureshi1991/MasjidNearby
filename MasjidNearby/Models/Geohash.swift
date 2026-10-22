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
}
