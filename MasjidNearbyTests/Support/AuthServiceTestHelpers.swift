import Foundation
@testable import MasjidNearby

/// The service's current state: a fresh subscription is sent the latest state first.
func currentState(of service: any AuthService) async -> AuthState? {
    var iterator = await service.authStates().makeAsyncIterator()
    return await iterator.next()
}
