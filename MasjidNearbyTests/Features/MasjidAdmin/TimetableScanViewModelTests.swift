import Foundation
import Testing
@testable import MasjidNearby

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
