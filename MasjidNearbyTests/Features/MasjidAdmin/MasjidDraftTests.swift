import Foundation
import Testing
@testable import MasjidNearby

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
