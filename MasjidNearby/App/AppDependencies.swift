import Foundation

/// Single composition root. Coordinators receive this and hand
/// protocol-typed services to ViewModels.
struct AppDependencies: Sendable {
    let authService: any AuthService

    /// Phase 3 replaces `MockAuthService` with the live Firebase implementation.
    static func makeDefault() -> AppDependencies {
        AppDependencies(authService: MockAuthService())
    }
}
