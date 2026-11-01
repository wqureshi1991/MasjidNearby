import Foundation

/// Failures from data services (Firestore, MapKit). Implementations map their own errors into these.
enum RepositoryError: Error, Sendable, Equatable, LocalizedError {
    case network
    case permissionDenied
    case notFound
    case invalidData(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .network:
            "Can't reach the server. Check your connection and try again."
        case .permissionDenied:
            "You don't have permission to do that."
        case .notFound:
            "That item no longer exists."
        case .invalidData(let detail):
            "Some data couldn't be read: \(detail)"
        case .unknown(let message):
            message
        }
    }
}
