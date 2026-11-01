import Foundation

/// Twilight conventions. Raw values are stored in Firestore; do not rename them.
enum CalculationMethod: String, Sendable, Hashable, Codable, CaseIterable {
    case isna
    case muslimWorldLeague = "mwl"
    case ummAlQura
    case egyptian
    case karachi

    /// Degrees the sun is below the horizon at Fajr.
    var fajrAngle: Double {
        switch self {
        case .isna: 15
        case .muslimWorldLeague: 18
        case .ummAlQura: 18.5
        case .egyptian: 19.5
        case .karachi: 18
        }
    }

    var ishaRule: IshaRule {
        switch self {
        case .isna: .angle(15)
        case .muslimWorldLeague: .angle(17)
        // Umm al-Qura uses 120 minutes during Ramadan; that needs a Hijri calendar and is not applied here.
        case .ummAlQura: .minutesAfterMaghrib(90)
        case .egyptian: .angle(17.5)
        case .karachi: .angle(18)
        }
    }
}
