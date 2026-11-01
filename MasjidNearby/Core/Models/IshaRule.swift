import Foundation

/// How Isha is determined: by twilight angle, or as a fixed interval after Maghrib.
enum IshaRule: Sendable, Hashable {
    case angle(Double)
    case minutesAfterMaghrib(Int)
}
