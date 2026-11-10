import FirebaseFirestore
import Foundation

/// Reads and writes `users/{uid}`. The only auth type that talks to Firestore.
struct FirestoreUserProfileStore: UserProfileStore {
    func role(for uid: String) async throws -> UserRole? {
        let snapshot: DocumentSnapshot
        do {
            snapshot = try await Self.document(for: uid).getDocument()
        } catch {
            throw Self.map(error)
        }
        guard snapshot.exists, let data = snapshot.data() else { return nil }
        return try UserProfileDTO(data: data).role
    }

    func createProfile(uid: String, role: UserRole) async throws {
        var data = UserProfileDTO(role: role).data
        data["createdAt"] = FieldValue.serverTimestamp()
        do {
            try await Self.document(for: uid).setData(data)
        } catch {
            throw Self.map(error)
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
