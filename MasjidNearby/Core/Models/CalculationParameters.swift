import Foundation

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
