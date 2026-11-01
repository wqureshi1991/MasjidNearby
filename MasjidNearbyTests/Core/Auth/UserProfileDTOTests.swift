import Foundation
import Testing
@testable import MasjidNearby

struct UserProfileDTOTests {
    @Test func decodesARole() throws {
        #expect(try UserProfileDTO(data: ["role": "masjidAdmin", "createdAt": Date()]).role == .masjidAdmin)
        #expect(try UserProfileDTO(data: ["role": "user"]).role == .user)
    }

    @Test func missingOrUnknownRoleThrowsProfileMissing() {
        #expect(throws: AuthError.profileMissing) { try UserProfileDTO(data: [:]) }
        #expect(throws: AuthError.profileMissing) { try UserProfileDTO(data: ["role": "superAdmin"]) }
        #expect(throws: AuthError.profileMissing) { try UserProfileDTO(data: ["role": 1]) }
    }

    @Test func encodesTheRoleRawValue() {
        #expect(UserProfileDTO(role: .masjidAdmin).data["role"] as? String == "masjidAdmin")
    }
}
