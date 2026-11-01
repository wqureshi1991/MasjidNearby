import Foundation
import Testing
@testable import MasjidNearby

struct CredentialRulesTests {
    @Test func acceptsPlausibleEmails() {
        for email in ["a@b.co", "imam.ali@masjid.org", "  padded@example.com  "] {
            #expect(CredentialRules.isPlausibleEmail(email), "\(email)")
        }
    }

    @Test func rejectsImplausibleEmails() {
        for email in ["", "plain", "@example.com", "a@", "a@example", "a@.com", "a@example.", "a b@example.com", "a@b@c.com"] {
            #expect(!CredentialRules.isPlausibleEmail(email), "\(email)")
        }
    }

    @Test func passwordNeedsSixCharacters() {
        #expect(!CredentialRules.isAcceptablePassword("12345"))
        #expect(CredentialRules.isAcceptablePassword("123456"))
    }
}
