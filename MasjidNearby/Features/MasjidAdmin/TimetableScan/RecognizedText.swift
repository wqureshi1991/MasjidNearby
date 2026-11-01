import Foundation

/// A piece of text found in a photo. Positions are normalised to 0...1 with the
/// origin at the bottom left, as Vision reports them.
struct RecognizedText: Sendable, Equatable {
    let text: String
    let minX: Double
    let midY: Double
    let height: Double
}
