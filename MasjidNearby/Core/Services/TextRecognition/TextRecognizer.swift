import Foundation
import ImageIO
import Vision

/// Finds printed text in a photo.
protocol TextRecognizer: Sendable {
    func recognizeText(in imageData: Data) async throws -> [RecognizedText]
}
