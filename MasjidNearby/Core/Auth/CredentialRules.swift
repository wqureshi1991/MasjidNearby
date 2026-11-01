import Foundation

/// Client-side checks that catch typos before a network round trip.
/// The backend stays the source of truth.
enum CredentialRules {
    /// Firebase Auth's own minimum.
    static let minimumPasswordLength = 6

    static func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isPlausibleEmail(_ email: String) -> Bool {
        let trimmed = normalizedEmail(email)
        guard !trimmed.contains(where: \.isWhitespace),
              let at = trimmed.firstIndex(of: "@")
        else { return false }
        let local = trimmed[..<at]
        let domain = trimmed[trimmed.index(after: at)...]
        return !local.isEmpty
            && !domain.contains("@")
            && domain.contains(".")
            && !domain.hasPrefix(".")
            && !domain.hasSuffix(".")
    }

    static func isAcceptablePassword(_ password: String) -> Bool {
        password.count >= minimumPasswordLength
    }
}
