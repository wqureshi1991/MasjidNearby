import Foundation

/// Whether the app may show notifications.
enum NotificationAuthorization: Sendable, Equatable {
    case notDetermined
    case denied
    case authorized
}
