import Foundation
import Testing
@testable import MasjidNearby

/// Display text and picker values the schedule editor's views read from its ViewModel.
@MainActor
struct SchedulePresentationTests {
    /// 2026-10-21 18:00 UTC: 11:00 on 21 October in California.
    private let now = Fixtures.day("2026-10-21").startOfDayUTC.addingTimeInterval(18 * 3_600)

    private func makeViewModel() -> ScheduleEditorViewModel {
        ScheduleEditorViewModel(
            masjid: Fixtures.masjid(),
            repository: MockMasjidRepository(),
            calculator: MockPrayerTimeCalculator(result: .success(Fixtures.times(on: "2026-10-21"))),
            now: now
        )
    }

    @Test func publishTitleAndStatusFollowEdits() {
        let viewModel = makeViewModel()
        #expect(viewModel.publishTitle == "Nothing to Publish")
        #expect(viewModel.statusSymbol == "function")
        #expect(viewModel.publishFooter == nil)

        viewModel.editingDay.fajr.hasIqamah = true
        #expect(viewModel.publishTitle == "Publish 1 Day")
        #expect(viewModel.statusText == "Edited. Not yet published.")
    }

    @Test func problemsShowInThePublishFooter() {
        let viewModel = makeViewModel()
        viewModel.editingDay.sunrise = Fixtures.time("04:00")
        #expect(viewModel.publishFooter == "Fix the problems on 1 edited day before publishing.")
    }

    @Test func pickerDateMapsToTheSameCalendarDay() {
        let viewModel = makeViewModel()
        let tomorrow = Fixtures.day("2026-10-22")

        viewModel.selectedDate = tomorrow.startOfDayUTC.addingTimeInterval(3_600)

        #expect(viewModel.selectedDay == tomorrow)
        #expect(viewModel.selectableDates.contains(viewModel.selectedDate))
    }
}
