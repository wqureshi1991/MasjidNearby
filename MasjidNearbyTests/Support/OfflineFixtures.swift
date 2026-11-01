import Foundation
import SwiftData
import Testing
@testable import MasjidNearby

/// Shared by the offline and favorites tests.
enum OfflineFixtures {
    /// 2026-10-21 12:00 in California.
    static let noon = Fixtures.day("2026-10-21").startOfDayUTC.addingTimeInterval(19 * 3_600)

    /// Both stores must behave the same, so every contract test runs against each.
    static func makeStores() throws -> [any OfflineStore] {
        let container = try ModelContainer(
            for: FavoriteMasjidRecord.self, CachedScheduleDayRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return [InMemoryOfflineStore(), SwiftDataOfflineStore(modelContainer: container)]
    }

    static func masjid(_ id: String, name: String = "Masjid") -> Masjid {
        let base = Fixtures.masjid(id: id, isVerified: true)
        return Masjid(id: id, name: name, address: base.address, coordinates: base.coordinates,
                      timeZoneIdentifier: base.timeZoneIdentifier, calculation: base.calculation,
                      jumuah: base.jumuah, isVerified: true)
    }
}
