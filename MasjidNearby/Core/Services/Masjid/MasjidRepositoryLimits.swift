import Foundation

enum MasjidRepositoryLimits {
    /// Firestore allows 500 writes per batch; stay well under it.
    static let maximumDaysPerPublish = 400
}
