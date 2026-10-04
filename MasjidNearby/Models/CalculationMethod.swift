import Foundation

/// How Isha is determined: by twilight angle, or as a fixed interval after Maghrib.
enum IshaRule: Sendable, Hashable {
    case angle(Double)
    case minutesAfterMaghrib(Int)
}

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

enum AsrMadhab: String, Sendable, Hashable, Codable, CaseIterable {
    /// Shafi'i, Maliki and Hanbali: shadow equals the object's length.
    case standard
    /// Hanafi: shadow equals twice the object's length.
    case hanafi

    var shadowFactor: Double {
        switch self {
        case .standard: 1
        case .hanafi: 2
        }
    }
}

/// What to do where twilight lasts all night, or nearly, and Fajr/Isha angles are never reached.
enum HighLatitudeRule: String, Sendable, Hashable, Codable, CaseIterable {
    /// No adjustment. Calculation fails where the angle is never reached.
    case none
    /// Fajr and Isha are at most half the night from sunrise and sunset.
    case middleOfNight
    /// Fajr and Isha are at most one seventh of the night from sunrise and sunset.
    case seventhOfNight
    /// The night portion is angle / 60 of the night.
    case twilightAngle
}

struct CalculationParameters: Sendable, Hashable, Codable {
    let method: CalculationMethod
    let asrMadhab: AsrMadhab
    let highLatitudeRule: HighLatitudeRule

    init(method: CalculationMethod,
         asrMadhab: AsrMadhab = .standard,
         highLatitudeRule: HighLatitudeRule = .middleOfNight) {
        self.method = method
        self.asrMadhab = asrMadhab
        self.highLatitudeRule = highLatitudeRule
    }
}
