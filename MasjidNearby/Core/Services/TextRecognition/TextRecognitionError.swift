import Foundation
import ImageIO
import Vision

enum TextRecognitionError: LocalizedError, Sendable {
    case unreadableImage

    var errorDescription: String? {
        switch self {
        case .unreadableImage: "That photo couldn't be opened. Try another one."
        }
    }
}
