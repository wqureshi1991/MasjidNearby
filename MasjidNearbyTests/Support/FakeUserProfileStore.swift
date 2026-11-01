import Foundation
@testable import MasjidNearby

actor FakeUserProfileStore: UserProfileStore {
    private(set) var roles: [String: UserRole]
    private var readError: AuthError?
    private var writeError: AuthError?

    init(roles: [String: UserRole] = [:]) {
        self.roles = roles
    }

    func failReads(with error: AuthError) {
        readError = error
    }

    func failWrites(with error: AuthError) {
        writeError = error
    }

    func role(for uid: String) throws -> UserRole? {
        if let readError { throw readError }
        return roles[uid]
    }

    func createProfile(uid: String, role: UserRole) throws {
        if let writeError { throw writeError }
        roles[uid] = role
    }
}
