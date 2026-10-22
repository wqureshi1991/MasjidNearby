import Foundation
import Testing
@testable import MasjidNearby

enum Fixtures {
    static let sanJose = Coordinates(latitude: 37.3382, longitude: -121.8863)

    static func time(_ string: String) -> WallClockTime {
        WallClockTime(string) ?? WallClockTime(wrappingMinutesSinceMidnight: 0)
    }

    static func masjid(id: String = "m1", isVerified: Bool = false) -> Masjid {
        Masjid(
            id: id,
            name: "Masjid Al-Noor",
            address: "1 Main St, San Jose, CA",
            coordinates: sanJose,
            timeZoneIdentifier: "America/Los_Angeles",
            calculation: CalculationParameters(method: .isna, asrMadhab: .hanafi),
            jumuah: [JumuahSlot(khutbah: time("13:15"), iqamah: time("13:45")), JumuahSlot(khutbah: time("14:30"))],
            isVerified: isVerified
        )
    }

    static func day(_ key: String) -> CalendarDay {
        CalendarDay(key: key) ?? CalendarDay(julianDayNumber: 2_440_588)
    }

    static func times(on key: String, fajr: String = "05:53", fajrIqamah: String? = nil,
                      dhuhr: String = "12:57", source: PrayerTimeSource = .calculated) -> DailyPrayerTimes {
        DailyPrayerTimes(
            day: day(key),
            fajr: PrayerTime(adhan: time(fajr), iqamah: fajrIqamah.map(time)),
            sunrise: time("07:04"),
            dhuhr: PrayerTime(adhan: time(dhuhr)),
            asr: PrayerTime(adhan: time("16:17")),
            maghrib: PrayerTime(adhan: time("18:49")),
            isha: PrayerTime(adhan: time("20:01")),
            source: source
        )
    }
}

struct GeohashTests {
    @Test func matchesPublishedReferenceValues() {
        // Reference values from the geohash.org / Wikipedia examples.
        #expect(Geohash.encode(Coordinates(latitude: 57.64911, longitude: 10.40744), precision: 11) == "u4pruydqqvj")
        #expect(Geohash.encode(Coordinates(latitude: 42.6, longitude: -5.6), precision: 5) == "ezs42")
    }

    @Test func encodesKnownCities() {
        #expect(Geohash.encode(Fixtures.sanJose) == "9q9k6mjng")
        #expect(Geohash.encode(Coordinates(latitude: -33.8688, longitude: 151.2093), precision: 6) == "r3gx2f")
    }

    @Test func nearbyPointsShareAPrefix() {
        let a = Geohash.encode(Fixtures.sanJose, precision: 6)
        let b = Geohash.encode(Coordinates(latitude: 37.3390, longitude: -121.8870), precision: 6)
        #expect(a.prefix(5) == b.prefix(5))
    }

    @Test func clampsPrecision() {
        #expect(Geohash.encode(Fixtures.sanJose, precision: 0).count == 1)
        #expect(Geohash.encode(Fixtures.sanJose, precision: 40).count == 12)
    }
}

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

struct ScheduleValidatorTests {
    @Test func calculatedDayHasNoIssues() {
        #expect(ScheduleValidator.issues(in: Fixtures.times(on: "2026-10-21")).isEmpty)
    }

    @Test func flagsPrayersOutOfOrder() {
        let times = Fixtures.times(on: "2026-10-21", dhuhr: "06:30")
        #expect(ScheduleValidator.issues(in: times).contains(.outOfOrder(earlier: "Sunrise", later: "Dhuhr")))
    }

    @Test func flagsIqamahBeforeAdhanAndTooLate() {
        let before = Fixtures.times(on: "2026-10-21", fajr: "05:53", fajrIqamah: "05:40")
        #expect(ScheduleValidator.issues(in: before) == [.iqamahBeforeAdhan(.fajr)])

        let late = Fixtures.times(on: "2026-10-21", fajr: "05:00", fajrIqamah: "07:30")
        #expect(ScheduleValidator.issues(in: late).contains(.iqamahTooLate(.fajr)))
    }

    @Test func allowsIshaAfterMidnight() {
        let times = DailyPrayerTimes(
            day: Fixtures.day("2026-06-21"),
            fajr: PrayerTime(adhan: Fixtures.time("01:30")),
            sunrise: Fixtures.time("04:43"),
            dhuhr: PrayerTime(adhan: Fixtures.time("13:03")),
            asr: PrayerTime(adhan: Fixtures.time("17:26")),
            maghrib: PrayerTime(adhan: Fixtures.time("21:22")),
            isha: PrayerTime(adhan: Fixtures.time("00:40"), iqamah: Fixtures.time("00:50")),
            source: .manual
        )
        #expect(ScheduleValidator.issues(in: times).isEmpty)
    }
}

struct MasjidDraftTests {
    @Test func emptyDraftListsEveryMissingField() {
        let problems = MasjidDraft().problems
        #expect(problems.contains(.missingName))
        #expect(problems.contains(.missingAddress))
        #expect(problems.contains(.missingLocation))
        #expect(MasjidDraft().makeMasjid(id: "x", isVerified: false) == nil)
    }

    @Test func draftFromMasjidRoundTrips() {
        let masjid = Fixtures.masjid()
        let draft = MasjidDraft(masjid: masjid)
        #expect(draft.problems.isEmpty)
        #expect(draft.makeMasjid(id: masjid.id, isVerified: masjid.isVerified) == masjid)
    }

    @Test func trimsNameAndAddressAndSortsJumuah() {
        var draft = MasjidDraft(masjid: Fixtures.masjid())
        draft.name = "  Masjid Al-Noor \n"
        draft.jumuah.reverse()

        let masjid = draft.makeMasjid(id: "m1", isVerified: false)

        #expect(masjid?.name == "Masjid Al-Noor")
        #expect(masjid?.jumuah.first?.khutbah == Fixtures.time("13:15"))
    }

    @Test func rejectsJumuahIqamahBeforeKhutbah() {
        var draft = MasjidDraft(masjid: Fixtures.masjid())
        draft.jumuah[0].iqamah = Fixtures.time("13:00")
        #expect(draft.problems == [.jumuahIqamahBeforeKhutbah])
    }

    @Test func rejectsUnknownTimeZone() {
        var draft = MasjidDraft(masjid: Fixtures.masjid())
        draft.timeZoneIdentifier = "Mars/Olympus_Mons"
        #expect(draft.problems == [.unknownTimeZone])
    }
}

struct EditingModelTests {
    @Test func hiddenIqamahDoesNotAffectEquality() {
        var a = EditablePrayer(PrayerTime(adhan: Fixtures.time("05:53")))
        var b = a
        b.iqamah = Fixtures.time("06:30")
        #expect(a == b)

        a.hasIqamah = true
        #expect(a != b)
        #expect(a.prayerTime.iqamah == Fixtures.time("06:08"))
    }

    @Test func editableDayProducesManualTimesForAnyDay() {
        let editable = EditableDay(Fixtures.times(on: "2026-10-21", fajrIqamah: "06:15"))
        let moved = editable.dailyTimes(on: Fixtures.day("2026-10-25"))
        #expect(moved.day.key == "2026-10-25")
        #expect(moved.source == .manual)
        #expect(moved.fajr.iqamah == Fixtures.time("06:15"))
    }

    @Test func wallClockTimeFromDateUsesTheTimeZone() throws {
        let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
        // 2026-10-21 20:30 UTC is 13:30 in California (PDT).
        let instant = Fixtures.day("2026-10-21").startOfDayUTC.addingTimeInterval(20.5 * 3_600)
        #expect(WallClockTime(date: instant, in: losAngeles) == Fixtures.time("13:30"))
        #expect(WallClockTime(date: Fixtures.time("13:30").pickerDate(in: losAngeles), in: losAngeles) == Fixtures.time("13:30"))
    }

    @Test func minutesUntilWrapsPastMidnight() {
        #expect(Fixtures.time("23:50").minutes(until: Fixtures.time("00:10")) == 20)
        #expect(Fixtures.time("05:00").minutes(until: Fixtures.time("05:15")) == 15)
    }
}
