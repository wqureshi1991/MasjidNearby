import Foundation
import Testing
@testable import MasjidNearby

struct DemoDataTests {
    @Test func seedsVerifiedSampleMasjidsWithOnePublishedSchedule() async throws {
        let now = Fixtures.day("2026-10-21").startOfDayUTC.addingTimeInterval(19 * 3_600)
        let repository = DemoData.repository(now: now)

        let masjids = try await repository.verifiedMasjids(near: Fixtures.sanJose, radiusMeters: 25_000)
        #expect(masjids.count == 3)
        #expect(masjids.allSatisfy { $0.name.hasPrefix("Sample") })

        let today = Fixtures.day("2026-10-21")
        let published = try await repository.schedule(masjidID: "sample-downtown", from: today, through: today)
        #expect(published.first?.source == .manual)
        #expect(published.first?.fajr.iqamah != nil)
        #expect(try await repository.schedule(masjidID: "sample-milpitas", from: today, through: today).isEmpty)
    }
}
