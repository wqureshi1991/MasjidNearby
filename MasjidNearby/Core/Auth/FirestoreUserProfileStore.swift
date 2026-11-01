import FirebaseFirestore
import Foundation

/// Reads and writes `users/{uid}`. The only auth type that talks to Firestore.
struct FirestoreUserProfileStore: UserProfileStore {
    func role(for uid: String) async throws -> UserRole? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UserRole?, any Error>) in
            Self.document(for: uid).getDocument { snapshot, error in
                if let error {
                    continuation.resume(throwing: Self.map(error))
                    return
                }
                guard let snapshot, snapshot.exists, let data = snapshot.data() else {
                    continuation.resume(returning: nil)
                    return
                }
                do {
                    continuation.resume(returning: try UserProfileDTO(data: data).role)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func createProfile(uid: String, role: UserRole) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            var data = UserProfileDTO(role: role).data
            data["createdAt"] = FieldValue.serverTimestamp()
            Self.document(for: uid).setData(data) { error in
                if let error {
                    continuation.resume(throwing: Self.map(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func document(for uid: String) -> DocumentReference {
        Firestore.firestore().collection("users").document(uid)
    }

    private static func map(_ error: any Error) -> AuthError {
        if let firestoreError = error as? FirestoreErrorCode, firestoreError.code == .unavailable {
            return .network
        }
        return .unknown(error.localizedDescription)
    }
}
