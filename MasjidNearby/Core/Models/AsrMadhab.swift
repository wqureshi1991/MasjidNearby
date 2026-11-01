import Foundation

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
