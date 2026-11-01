import Foundation
import ImageIO
import Vision

/// Returns canned text. For tests and previews.
struct MockTextRecognizer: TextRecognizer {
    let result: Result<[RecognizedText], TextRecognitionError>

    /// One fragment per line, top to bottom.
    init(lines: [String]) {
        result = .success(lines.enumerated().map { index, line in
            RecognizedText(text: line, minX: 0.05, midY: 0.95 - Double(index) * 0.03, height: 0.02)
        })
    }

    init(result: Result<[RecognizedText], TextRecognitionError>) {
        self.result = result
    }

    func recognizeText(in imageData: Data) async throws -> [RecognizedText] {
        try result.get()
    }
}
