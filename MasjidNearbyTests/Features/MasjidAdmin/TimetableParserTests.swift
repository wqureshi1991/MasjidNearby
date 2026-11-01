import Foundation
import Testing
@testable import MasjidNearby

struct TimetableParserTests {
    @Test func readsAUSTimetable() throws {
        let lines = TimetableFixtures.usLines
        let layout = try #require(TimetableParser.detectLayout(in: lines))
        let parsed = TimetableParser.parse(lines: lines, layout: layout)

        #expect(layout == .adhanWithSunrise)
        #expect(parsed.days.map(\.dayOfMonth) == [1, 2, 3, 4, 5])

        let first = parsed.days[0]
        #expect(first.values[.adhan(.fajr)] == TimetableFixtures.t("05:42"))
        #expect(first.values[.sunrise] == TimetableFixtures.t("06:58"))
        #expect(first.values[.adhan(.dhuhr)] == TimetableFixtures.t("12:57"))
        #expect(first.values[.adhan(.asr)] == TimetableFixtures.t("16:17"))
        #expect(first.values[.adhan(.maghrib)] == TimetableFixtures.t("18:49"))
        #expect(first.values[.adhan(.isha)] == TimetableFixtures.t("20:01"))
        #expect(first.flagged.isEmpty)
    }

    @Test func fixesAndFlagsCommonOCRSlips() {
        let parsed = TimetableParser.parse(lines: TimetableFixtures.usLines, layout: .adhanWithSunrise)
        let third = parsed.days[2]
        #expect(third.values[.adhan(.fajr)] == TimetableFixtures.t("05:40"))
        #expect(third.values[.sunrise] == TimetableFixtures.t("07:01"))
        #expect(third.flagged == [.adhan(.fajr), .sunrise])
    }

    @Test func readsAmPmAndIgnoresHijriDates() {
        let parsed = TimetableParser.parse(lines: TimetableFixtures.usLines, layout: .adhanWithSunrise)
        #expect(parsed.days[3].values[.adhan(.dhuhr)] == TimetableFixtures.t("12:56"))
        #expect(parsed.days[3].values[.adhan(.isha)] == TimetableFixtures.t("19:57"))
        #expect(parsed.days[4].dayOfMonth == 5)
        #expect(parsed.days[4].values[.adhan(.fajr)] == TimetableFixtures.t("05:46"))
    }

    @Test func readsAdhanAndIqamahColumns() throws {
        let lines = TimetableFixtures.ukLines
        let layout = try #require(TimetableParser.detectLayout(in: lines))
        let parsed = TimetableParser.parse(lines: lines, layout: layout)

        #expect(layout == .adhanAndIqamahWithSunrise)
        // Day 23 is missing a time, so it's skipped rather than guessed.
        #expect(parsed.days.map(\.dayOfMonth) == [21, 22])
        #expect(parsed.days[1].values[.adhan(.fajr)] == TimetableFixtures.t("05:43"))
        #expect(parsed.days[1].values[.iqamah(.fajr)] == TimetableFixtures.t("06:10"))
        #expect(parsed.days[1].values[.iqamah(.isha)] == TimetableFixtures.t("20:30"))
    }

    @Test func detectsFiveColumnTimetables() {
        let lines = ["1 5:42 12:57 4:17 6:49 8:01", "2 5:43 12:57 4:16 6:48 8:00"]
        #expect(TimetableParser.detectLayout(in: lines) == .adhanOnly)
        #expect(TimetableParser.parse(lines: lines, layout: .adhanOnly).days.count == 2)
    }

    @Test func findsNothingWithoutTimetableRows() {
        #expect(TimetableParser.detectLayout(in: ["Masjid Al-Noor", "Jumuah 1:15pm"]) == nil)
    }

    @Test func flagsTimesThatCantExist() {
        let parsed = TimetableParser.parse(lines: ["1 Thu 5:42 6:58 12:57 4:17 6:49 8:61"], layout: .adhanWithSunrise)
        #expect(parsed.days[0].values[.adhan(.isha)] == nil)
        #expect(parsed.days[0].flagged == [.adhan(.isha)])
    }

    @Test func groupsFragmentsIntoLines() {
        func fragment(_ text: String, _ x: Double, _ y: Double, _ height: Double = 0.02) -> RecognizedText {
            RecognizedText(text: text, minX: x, midY: y, height: height)
        }
        let fragments = [
            fragment("1", 0.05, 0.800), fragment("Thu", 0.10, 0.801), fragment("5:42", 0.25, 0.799),
            fragment("6:58", 0.35, 0.802), fragment("12:57", 0.45, 0.800), fragment("4:17", 0.55, 0.798),
            fragment("6:49", 0.65, 0.801), fragment("8:01", 0.75, 0.800),
            fragment("2", 0.05, 0.770), fragment("Fri", 0.10, 0.771), fragment("5:43 6:59", 0.25, 0.769),
            fragment("12:57 4:16 6:48 8:00", 0.45, 0.771),
            fragment("October 2026", 0.40, 0.900, 0.03),
        ]
        #expect(TimetableParser.lines(from: fragments) == [
            "October 2026",
            "1 Thu 5:42 6:58 12:57 4:17 6:49 8:01",
            "2 Fri 5:43 6:59 12:57 4:16 6:48 8:00",
        ])
    }
}
