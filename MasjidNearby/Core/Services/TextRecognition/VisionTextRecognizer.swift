import Foundation
import ImageIO
import Vision

/// On-device text recognition with Vision. Nothing leaves the phone.
struct VisionTextRecognizer: TextRecognizer {
    func recognizeText(in imageData: Data) async throws -> [RecognizedText] {
        // Recognition takes a second or two, so keep it off the main actor.
        try await Task.detached(priority: .userInitiated) {
            try Self.recognize(imageData)
        }.value
    }

    private static func recognize(_ data: Data) throws -> [RecognizedText] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw TextRecognitionError.unreadableImage }

        // Photos are often stored sideways with an EXIF orientation; Vision needs to know it.
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let rawOrientation = properties?[kCGImagePropertyOrientation] as? UInt32 ?? 1
        let orientation = CGImagePropertyOrientation(rawValue: rawOrientation) ?? .up

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Language correction "fixes" times into words, so leave it off.
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
        try handler.perform([request])

        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let box = observation.boundingBox
            return RecognizedText(text: candidate.string,
                                  minX: Double(box.minX),
                                  midY: Double(box.midY),
                                  height: Double(box.height))
        }
    }
}
