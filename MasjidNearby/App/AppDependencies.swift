import Foundation

/// Single composition root. Coordinators receive this and hand
/// protocol-typed services to ViewModels.
struct AppDependencies: Sendable {
    let authService: any AuthService

    static func makeDefault(firebaseConfigured: Bool) -> AppDependencies {
        guard firebaseConfigured else {
            return AppDependencies(authService: MockAuthService())
        }
        return AppDependencies(
            authService: LiveAuthService(backend: FirebaseAuthBackend(), profiles: FirestoreUserProfileStore())
        )
    }
}
