import Foundation
import Testing
@testable import MasjidNearby

struct AuthErrorMapperTests {
    @Test func mapsFirebaseAuthCodes() {
        let cases: [(code: Int, expected: AuthError)] = [
            (17008, .invalidEmail),
            (17009, .wrongCredentials),
            (17004, .wrongCredentials),
            (17011, .wrongCredentials),
            (17007, .emailAlreadyInUse),
            (17026, .weakPassword),
            (17005, .accountDisabled),
            (17010, .tooManyAttempts),
            (17020, .network),
        ]
        for (code, expected) in cases {
            let error = NSError(domain: "FIRAuthErrorDomain", code: code)
            #expect(AuthErrorMapper.map(error) == expected, "code \(code)")
        }
    }

    @Test func unknownCodeAndOtherDomainsBecomeUnknown() {
        let unhandled = NSError(domain: "FIRAuthErrorDomain", code: 17999,
                                userInfo: [NSLocalizedDescriptionKey: "Something odd"])
        #expect(AuthErrorMapper.map(unhandled) == .unknown("Something odd"))

        let other = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut,
                            userInfo: [NSLocalizedDescriptionKey: "Timed out"])
        #expect(AuthErrorMapper.map(other) == .unknown("Timed out"))
    }

    @Test func authErrorsPassThrough() {
        #expect(AuthErrorMapper.map(AuthError.profileMissing) == .profileMissing)
    }
}
