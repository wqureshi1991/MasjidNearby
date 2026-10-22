import FirebaseFirestore
import Foundation
import OSLog

/// The only masjid type that talks to Firestore. Like the auth wrappers, it uses
/// completion-handler APIs and hands back plain `Sendable` values.
struct FirestoreMasjidRepository: MasjidRepository {
    /// Firestore never calls a write's completion while offline: the write is queued and
    /// uploaded on reconnect. Stop waiting after this long and treat the write as saved.
    private static let writeTimeout: TimeInterval = 15
    private static let logger = Logger(subsystem: "com.waqarqureshi.MasjidNearby", category: "MasjidRepository")

    func masjid(administeredBy adminUID: String) async throws -> Masjid? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Masjid?, any Error>) in
            Self.masjids
                .whereField(MasjidDTO.Key.adminUIDs, arrayContains: adminUID)
                .limit(to: 1)
                .getDocuments { snapshot, error in
                    if let error {
                        continuation.resume(throwing: Self.map(error))
                        return
                    }
                    guard let document = snapshot?.documents.first else {
                        continuation.resume(returning: nil)
                        return
                    }
                    do {
                        continuation.resume(returning: try MasjidDTO.masjid(id: document.documentID, data: document.data()))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
        }
    }

    func createMasjid(from draft: MasjidDraft, adminUID: String) async throws -> Masjid {
        let reference = Self.masjids.document()
        guard let masjid = draft.makeMasjid(id: reference.documentID, isVerified: false) else {
            throw RepositoryError.invalidData("the masjid details are incomplete")
        }
        let data = Self.creationData(for: masjid, adminUID: adminUID)
        try await Self.write { completion in
            reference.setData(data, completion: completion)
        }
        return masjid
    }

    func updateMasjid(_ masjid: Masjid, with draft: MasjidDraft) async throws -> Masjid {
        guard let updated = draft.makeMasjid(id: masjid.id, isVerified: masjid.isVerified) else {
            throw RepositoryError.invalidData("the masjid details are incomplete")
        }
        var data = MasjidDTO.data(for: updated)
        data[MasjidDTO.Key.updatedAt] = FieldValue.serverTimestamp()
        let fields = data
        let reference = Self.masjids.document(masjid.id)
        try await Self.write { completion in
            reference.updateData(fields, completion: completion)
        }
        return updated
    }

    func verifiedMasjids(near center: Coordinates, radiusMeters: Double) async throws -> [Masjid] {
        // Query the geohash cell around the point and its neighbours, then filter by real distance.
        let prefixes = Geohash.coveringPrefixes(around: center, radiusMeters: radiusMeters)
        let candidates = try await withThrowingTaskGroup(of: [Masjid].self, returning: [Masjid].self) { group in
            for prefix in prefixes {
                group.addTask {
                    try await Self.verifiedMasjids(withGeohashPrefix: prefix)
                }
            }
            var unique: [String: Masjid] = [:]
            for try await batch in group {
                for masjid in batch {
                    unique[masjid.id] = masjid
                }
            }
            return Array(unique.values)
        }
        return candidates
            .map { (masjid: $0, distance: $0.coordinates.distance(to: center)) }
            .filter { $0.distance <= radiusMeters }
            .sorted { $0.distance < $1.distance }
            .map { $0.masjid }
    }

    func schedule(masjidID: String, from start: CalendarDay, through end: CalendarDay) async throws -> [DailyPrayerTimes] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[DailyPrayerTimes], any Error>) in
            Self.schedule(of: masjidID)
                .whereField(ScheduleDayDTO.Key.day, isGreaterThanOrEqualTo: start.key)
                .whereField(ScheduleDayDTO.Key.day, isLessThanOrEqualTo: end.key)
                .getDocuments { snapshot, error in
                    if let error {
                        continuation.resume(throwing: Self.map(error))
                        return
                    }
                    let documents = snapshot?.documents ?? []
                    do {
                        continuation.resume(returning: try documents.map { try ScheduleDayDTO.times(from: $0.data()) })
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
        }
    }

    func publish(_ days: [DailyPrayerTimes], masjidID: String) async throws {
        guard !days.isEmpty else { return }
        guard days.count <= MasjidRepositoryLimits.maximumDaysPerPublish else {
            throw RepositoryError.invalidData("publish at most \(MasjidRepositoryLimits.maximumDaysPerPublish) days at a time")
        }
        let collection = Self.schedule(of: masjidID)
        let batch = Firestore.firestore().batch()
        for day in days {
            var data = ScheduleDayDTO.data(for: day)
            data[ScheduleDayDTO.Key.updatedAt] = FieldValue.serverTimestamp()
            batch.setData(data, forDocument: collection.document(day.day.key))
        }
        try await Self.write { completion in
            batch.commit(completion: completion)
        }
    }

    // MARK: - Private

    private static var masjids: CollectionReference {
        Firestore.firestore().collection("masjids")
    }

    private static func schedule(of masjidID: String) -> CollectionReference {
        masjids.document(masjidID).collection("schedule")
    }

    private static func verifiedMasjids(withGeohashPrefix prefix: String) async throws -> [Masjid] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Masjid], any Error>) in
            masjids
                .whereField(MasjidDTO.Key.verified, isEqualTo: true)
                .whereField(MasjidDTO.Key.geohash, isGreaterThanOrEqualTo: prefix)
                // "~" sorts after every geohash character, so this is "starts with prefix".
                .whereField(MasjidDTO.Key.geohash, isLessThanOrEqualTo: prefix + "~")
                .getDocuments { snapshot, error in
                    if let error {
                        continuation.resume(throwing: Self.map(error))
                        return
                    }
                    var found: [Masjid] = []
                    for document in snapshot?.documents ?? [] {
                        do {
                            found.append(try MasjidDTO.masjid(id: document.documentID, data: document.data()))
                        } catch {
                            // One malformed masjid shouldn't hide the others.
                            Self.logger.error("Skipping masjid \(document.documentID, privacy: .public): \(error.localizedDescription, privacy: .public)")
                        }
                    }
                    continuation.resume(returning: found)
                }
        }
    }

    private static func creationData(for masjid: Masjid, adminUID: String) -> [String: Any] {
        var data = MasjidDTO.data(for: masjid)
        data[MasjidDTO.Key.adminUIDs] = [adminUID]
        data[MasjidDTO.Key.verified] = false
        data[MasjidDTO.Key.createdAt] = FieldValue.serverTimestamp()
        data[MasjidDTO.Key.updatedAt] = FieldValue.serverTimestamp()
        return data
    }

    /// Starts a write and waits for the server to confirm it, or for `writeTimeout`.
    private static func write(_ start: (@escaping @Sendable ((any Error)?) -> Void) -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let once = ResumeOnce(continuation)
            start { error in
                if let error {
                    once.resume(throwing: Self.map(error))
                } else {
                    once.resume(returning: ())
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + Self.writeTimeout) {
                if once.resume(returning: ()) {
                    Self.logger.notice("Write not confirmed in time; Firestore will upload it when online.")
                }
            }
        }
    }

    private static func map(_ error: any Error) -> RepositoryError {
        if let repositoryError = error as? RepositoryError {
            return repositoryError
        }
        if let firestoreError = error as? FirestoreErrorCode {
            switch firestoreError.code {
            case .unavailable:
                return .network
            case .permissionDenied, .unauthenticated:
                return .permissionDenied
            case .notFound:
                return .notFound
            default:
                break
            }
        }
        return .unknown(error.localizedDescription)
    }
}
