import Foundation
import Testing
@testable import MasjidNearby

struct LiveAuthServiceTests {
    // MARK: - Restoring a session at launch

    @Test func noSavedAccountRestoresSignedOut() async {
        let service = LiveAuthService(backend: FakeAuthBackend(), profiles: FakeUserProfileStore())
        #expect(await currentState(of: service) == .signedOut)
    }

    @Test func savedAccountRestoresWithItsStoredRole() async {
        let backend = FakeAuthBackend(current: AuthAccount(uid: "a1", isAnonymous: false))
        let profiles = FakeUserProfileStore(roles: ["a1": .masjidAdmin])
        let service = LiveAuthService(backend: backend, profiles: profiles)

        #expect(await currentState(of: service) == .signedIn(AuthSession(userID: "a1", role: .masjidAdmin)))
    }

    @Test func anonymousAccountRestoresAsGuestWithoutReadingAProfile() async {
        let backend = FakeAuthBackend(current: AuthAccount(uid: "anon", isAnonymous: true))
        let profiles = FakeUserProfileStore()
        await profiles.failReads(with: .network)
        let service = LiveAuthService(backend: backend, profiles: profiles)

        #expect(await currentState(of: service) == .signedIn(AuthSession(userID: "anon", role: .user, isGuest: true)))
    }

    @Test func accountWithNoProfileIsSignedOutAtLaunch() async {
        let backend = FakeAuthBackend(current: AuthAccount(uid: "a1", isAnonymous: false))
        let service = LiveAuthService(backend: backend, profiles: FakeUserProfileStore())

        #expect(await currentState(of: service) == .signedOut)
        #expect(await backend.signOutCount == 1)
    }

    @Test func profileReadFailureAtLaunchKeepsTheBackendSession() async {
        let backend = FakeAuthBackend(current: AuthAccount(uid: "a1", isAnonymous: false))
        let profiles = FakeUserProfileStore(roles: ["a1": .user])
        await profiles.failReads(with: .network)
        let service = LiveAuthService(backend: backend, profiles: profiles)

        #expect(await currentState(of: service) == .signedOut)
        #expect(await backend.signOutCount == 0)
    }

    // MARK: - Sign in

    @Test func signInUsesTheStoredRole() async throws {
        let backend = FakeAuthBackend()
        await backend.addAccount(email: "imam@example.com", password: "secret1", uid: "a1")
        let profiles = FakeUserProfileStore(roles: ["a1": .masjidAdmin])
        let service = LiveAuthService(backend: backend, profiles: profiles)

        try await service.signIn(email: "  imam@example.com ", password: "secret1")

        #expect(await currentState(of: service) == .signedIn(AuthSession(userID: "a1", role: .masjidAdmin)))
        #expect(await backend.receivedEmails == ["imam@example.com"])
    }

    @Test func wrongPasswordThrowsAndStaysSignedOut() async {
        let backend = FakeAuthBackend()
        await backend.addAccount(email: "a@example.com", password: "secret1", uid: "a1")
        let service = LiveAuthService(backend: backend, profiles: FakeUserProfileStore(roles: ["a1": .user]))

        await #expect(throws: AuthError.wrongCredentials) {
            try await service.signIn(email: "a@example.com", password: "nope")
        }
        #expect(await currentState(of: service) == .signedOut)
    }

    @Test func signInWithoutAProfileThrowsAndSignsTheBackendOut() async {
        let backend = FakeAuthBackend()
        await backend.addAccount(email: "a@example.com", password: "secret1", uid: "a1")
        let service = LiveAuthService(backend: backend, profiles: FakeUserProfileStore())

        await #expect(throws: AuthError.profileMissing) {
            try await service.signIn(email: "a@example.com", password: "secret1")
        }
        #expect(await backend.signOutCount == 1)
        #expect(await currentState(of: service) == .signedOut)
    }

    @Test func profileReadFailureDuringSignInSignsTheBackendOut() async {
        let backend = FakeAuthBackend()
        await backend.addAccount(email: "a@example.com", password: "secret1", uid: "a1")
        let profiles = FakeUserProfileStore(roles: ["a1": .user])
        await profiles.failReads(with: .network)
        let service = LiveAuthService(backend: backend, profiles: profiles)

        await #expect(throws: AuthError.network) {
            try await service.signIn(email: "a@example.com", password: "secret1")
        }
        #expect(await backend.signOutCount == 1)
    }

    // MARK: - Sign up

    @Test func signUpWritesTheProfileAndSignsIn() async throws {
        let backend = FakeAuthBackend()
        let profiles = FakeUserProfileStore()
        let service = LiveAuthService(backend: backend, profiles: profiles)

        try await service.signUp(email: "imam@example.com", password: "secret1", role: .masjidAdmin)

        #expect(await profiles.roles == ["uid-1": .masjidAdmin])
        #expect(await currentState(of: service) == .signedIn(AuthSession(userID: "uid-1", role: .masjidAdmin)))
    }

    @Test func failedProfileWriteDeletesTheNewAccount() async {
        let backend = FakeAuthBackend()
        let profiles = FakeUserProfileStore()
        await profiles.failWrites(with: .network)
        let service = LiveAuthService(backend: backend, profiles: profiles)

        await #expect(throws: AuthError.network) {
            try await service.signUp(email: "imam@example.com", password: "secret1", role: .masjidAdmin)
        }
        #expect(await backend.deletedUIDs == ["uid-1"])
        #expect(await currentState(of: service) == .signedOut)
    }

    @Test func existingEmailCannotSignUpAgain() async {
        let backend = FakeAuthBackend()
        await backend.addAccount(email: "a@example.com", password: "secret1", uid: "a1")
        let service = LiveAuthService(backend: backend, profiles: FakeUserProfileStore())

        await #expect(throws: AuthError.emailAlreadyInUse) {
            try await service.signUp(email: "a@example.com", password: "secret1", role: .user)
        }
    }

    // MARK: - Guest, reset, sign out

    @Test func guestSignsInAsAUser() async throws {
        let service = LiveAuthService(backend: FakeAuthBackend(), profiles: FakeUserProfileStore())

        try await service.continueAsGuest()

        #expect(await currentState(of: service) == .signedIn(AuthSession(userID: "anon-1", role: .user, isGuest: true)))
    }

    @Test func passwordResetPassesTheTrimmedEmail() async throws {
        let backend = FakeAuthBackend()
        let service = LiveAuthService(backend: backend, profiles: FakeUserProfileStore())

        try await service.sendPasswordReset(email: " a@example.com\n")

        #expect(await backend.receivedEmails == ["a@example.com"])
    }

    @Test func signOutEmitsSignedOut() async throws {
        let backend = FakeAuthBackend(current: AuthAccount(uid: "a1", isAnonymous: false))
        let service = LiveAuthService(backend: backend, profiles: FakeUserProfileStore(roles: ["a1": .user]))
        #expect(await currentState(of: service) == .signedIn(AuthSession(userID: "a1", role: .user)))

        try await service.signOut()

        #expect(await currentState(of: service) == .signedOut)
    }

    @Test func subscriberSeesEachChangeInOrder() async throws {
        let service = LiveAuthService(backend: FakeAuthBackend(), profiles: FakeUserProfileStore())
        var states = await service.authStates().makeAsyncIterator()
        let restored = await states.next()
        #expect(restored == .signedOut)

        try await service.continueAsGuest()
        let afterGuest = await states.next()
        #expect(afterGuest == .signedIn(AuthSession(userID: "anon-1", role: .user, isGuest: true)))

        try await service.signOut()
        let afterSignOut = await states.next()
        #expect(afterSignOut == .signedOut)
    }
}
