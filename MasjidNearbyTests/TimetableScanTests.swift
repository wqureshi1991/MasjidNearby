import Foundation
import Testing
@testable import MasjidNearby

private enum TimetableFixtures {
    /// A US-style timetable: 12-hour times without am/pm, OCR slips on day 3,
    /// a Hijri date on day 5, and header and footer lines.
    static let usLines = [
        "Masjid Al-Noor  October 2026",
        "Date Day Fajr Sunrise Dhuhr Asr Maghrib Isha",
        "1 Thu 5:42 6:58 12:57 4:17 6:49 8:01",
        "2 Fri 5:43 6:59 12:57 4:16 6:48 8:00",
        "3 Sat 5:4O 7:0l 12:57 4:15 6:46 7:58",
        "4 Sun 5:45am 7:02am 12:56pm 4:14pm 6:45pm 7:57pm",
        "5 Mon 23 5:46 7:03 12:56 4:13 6:44 7:56",
        "Jumuah 1:15pm and 2:30pm",
        "Tel 408 555 1234",
    ]

    /// A UK-style timetable: 24-hour adhan and iqamah, a dot separator, one short row.
    static let ukLines = [
        "21 Tue 05:42 06:10 07:04 12:57 13:30 15:46 16:15 18:49 18:54 20:01 20:30",
        "22 Wed 05.43 06:10 07:05 12:57 13:30 15:45 16:15 18:47 18:52 19:59 20:30",
        "23 Thu 05:44 06:10 07:06 12:57 13:30 15:44 16:15 18:46 18:51 19:58",
        "1:15 Jumuah",
    ]

    static func t(_ string: String) -> WallClockTime { Fixtures.time(string) }
}

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

@MainActor
struct TimetableScanViewModelTests {
    /// 1 October 2026, 13:00 in San Jose.
    private let now = Fixtures.day("2026-10-01").startOfDayUTC.addingTimeInterval(20 * 3_600)

    private func makeViewModel(lines: [String] = TimetableFixtures.usLines,
                               repository: MockMasjidRepository = MockMasjidRepository()) -> TimetableScanViewModel {
        TimetableScanViewModel(
            masjid: Fixtures.masjid(),
            repository: repository,
            calculator: MockPrayerTimeCalculator(result: .success(Fixtures.times(on: "2026-10-01"))),
            recognizer: MockTextRecognizer(lines: lines),
            now: now
        )
    }

    @Test func offersThisMonthAndTheNextTwo() {
        let viewModel = makeViewModel()
        #expect(viewModel.months == [Fixtures.day("2026-10-01"), Fixtures.day("2026-11-01"), Fixtures.day("2026-12-01")])
        #expect(viewModel.month == Fixtures.day("2026-10-01"))
    }

    @Test func scanBuildsDaysToReview() async {
        let viewModel = makeViewModel()
        await viewModel.load()
        await viewModel.scan(imageData: Data())

        #expect(viewModel.scanState.isLoaded)
        #expect(viewModel.layout == .adhanWithSunrise)
        #expect(viewModel.days.map(\.day) == (1...5).map { Fixtures.day("2026-10-0\($0)") })
        #expect(viewModel.days[0].times.asr.adhan == Fixtures.time("16:17"))
        #expect(viewModel.reviewCount == 1)
        #expect(viewModel.canPublish)
    }

    @Test func picksTheMonthPrintedOnTheTimetable() async {
        var lines = TimetableFixtures.usLines
        lines[0] = "Masjid Al-Noor  November 2026"
        let viewModel = makeViewModel(lines: lines)
        await viewModel.scan(imageData: Data())

        #expect(viewModel.month == Fixtures.day("2026-11-01"))
        #expect(viewModel.days.first?.day == Fixtures.day("2026-11-01"))
    }

    @Test func keepsPublishedIqamahWhenTheTimetableHasNone() async {
        let repository = MockMasjidRepository(published: [
            "m1": [Fixtures.times(on: "2026-10-02", fajrIqamah: "06:10", source: .manual)],
        ])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()
        await viewModel.scan(imageData: Data())

        #expect(viewModel.days[1].times.fajr.adhan == Fixtures.time("05:43"))
        #expect(viewModel.days[1].times.fajr.prayerTime.iqamah == Fixtures.time("06:10"))
    }

    @Test func reportsWhenNothingWasFound() async {
        let viewModel = makeViewModel(lines: ["A photo of a cat"])
        await viewModel.scan(imageData: Data())

        #expect(viewModel.scanState.error is TimetableScanError)
        #expect(!viewModel.hasResults)
        #expect(!viewModel.canPublish)
    }

    @Test func reportsRecognitionFailures() async {
        let viewModel = TimetableScanViewModel(
            masjid: Fixtures.masjid(),
            repository: MockMasjidRepository(),
            calculator: MockPrayerTimeCalculator(result: .success(Fixtures.times(on: "2026-10-01"))),
            recognizer: MockTextRecognizer(result: .failure(.unreadableImage)),
            now: now
        )
        await viewModel.scan(imageData: Data())
        #expect(viewModel.scanState.error is TextRecognitionError)
    }

    @Test func markingADayReviewedClearsItsFlags() async {
        let viewModel = makeViewModel()
        await viewModel.scan(imageData: Data())
        viewModel.markReviewed(Fixtures.day("2026-10-03"))
        #expect(viewModel.reviewCount == 0)
    }

    @Test func daysWithProblemsBlockPublishingUntilSkipped() async {
        let viewModel = makeViewModel()
        await viewModel.scan(imageData: Data())
        viewModel.days[0].times.sunrise = Fixtures.time("04:00")

        #expect(viewModel.daysWithIssues == 1)
        #expect(!viewModel.canPublish)

        viewModel.days[0].isIncluded = false
        #expect(viewModel.canPublish)
        #expect(viewModel.includedCount == 4)
    }

    @Test func publishesIncludedDaysAsScanned() async throws {
        let repository = MockMasjidRepository()
        let viewModel = makeViewModel(repository: repository)
        await viewModel.scan(imageData: Data())
        viewModel.days[4].isIncluded = false

        await viewModel.publish()

        if case .loaded(let count) = viewModel.publishState {
            #expect(count == 4)
        } else {
            Issue.record("Expected a publish result")
        }
        let saved = try await repository.schedule(masjidID: "m1", from: Fixtures.day("2026-10-01"),
                                                  through: Fixtures.day("2026-10-31"))
        #expect(saved.count == 4)
        #expect(saved.allSatisfy { $0.source == .ocr })
        #expect(saved[0].isha.adhan == Fixtures.time("20:01"))
    }

    @Test func publishFailureIsShown() async {
        let repository = MockMasjidRepository()
        let viewModel = makeViewModel(repository: repository)
        await viewModel.scan(imageData: Data())
        await repository.failNextCall(with: .network)

        await viewModel.publish()

        #expect(viewModel.publishState.error != nil)
    }

    @Test func changingTheLayoutRereadsThePhoto() async {
        let viewModel = makeViewModel()
        await viewModel.scan(imageData: Data())
        viewModel.layout = .adhanOnly

        #expect(viewModel.days.isEmpty)
        viewModel.layout = .adhanWithSunrise
        #expect(viewModel.days.count == 5)
    }
}
