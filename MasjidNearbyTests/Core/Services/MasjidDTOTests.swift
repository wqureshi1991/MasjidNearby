import Foundation
import Testing
@testable import MasjidNearby

struct MasjidDTOTests {
    @Test func roundTripsAMasjid() throws {
        let masjid = Fixtures.masjid(isVerified: true)
        var data = MasjidDTO.data(for: masjid)
        data[MasjidDTO.Key.verified] = true

        let decoded = try MasjidDTO.masjid(id: "m1", data: data)

        #expect(decoded == masjid)
        #expect(data[MasjidDTO.Key.geohash] as? String == "9q9k6mjng")
    }

    @Test func missingVerifiedFlagMeansUnverified() throws {
        let data = MasjidDTO.data(for: Fixtures.masjid())
        #expect(try MasjidDTO.masjid(id: "m1", data: data).isVerified == false)
    }

    @Test func unknownSettingsFallBackToDefaults() throws {
        var data = MasjidDTO.data(for: Fixtures.masjid())
        data[MasjidDTO.Key.calculationMethod] = "someFutureMethod"
        data[MasjidDTO.Key.asrMadhab] = nil

        let masjid = try MasjidDTO.masjid(id: "m1", data: data)

        #expect(masjid.calculation.method == .isna)
        #expect(masjid.calculation.asrMadhab == .standard)
    }

    @Test func missingRequiredFieldsThrow() {
        var data = MasjidDTO.data(for: Fixtures.masjid())
        data[MasjidDTO.Key.latitude] = nil
        #expect(throws: RepositoryError.self) { try MasjidDTO.masjid(id: "m1", data: data) }
    }

    @Test func invalidJumuahTimeThrows() {
        var data = MasjidDTO.data(for: Fixtures.masjid())
        data[MasjidDTO.Key.jumuah] = [["khutbah": "1:15 PM"]]
        #expect(throws: RepositoryError.self) { try MasjidDTO.masjid(id: "m1", data: data) }
    }

    @Test func roundTripsAScheduleDay() throws {
        let times = Fixtures.times(on: "2026-10-21", fajrIqamah: "06:15", source: .manual)
        let data = ScheduleDayDTO.data(for: times)

        #expect(data[ScheduleDayDTO.Key.day] as? String == "2026-10-21")
        #expect((data["fajr"] as? [String: String])?["iqamah"] == "06:15")
        #expect((data["dhuhr"] as? [String: String])?["iqamah"] == nil)
        #expect(try ScheduleDayDTO.times(from: data) == times)
    }

    @Test func scheduleDayWithBadTimeThrows() {
        var data = ScheduleDayDTO.data(for: Fixtures.times(on: "2026-10-21"))
        data["asr"] = ["adhan": "25:00"]
        #expect(throws: RepositoryError.self) { try ScheduleDayDTO.times(from: data) }
    }
}
