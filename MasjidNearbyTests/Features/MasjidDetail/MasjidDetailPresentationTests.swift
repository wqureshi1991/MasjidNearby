import Foundation
import Testing
@testable import MasjidNearby

/// Display decisions the masjid page's views read from its ViewModel.
@MainActor
struct MasjidDetailPresentationTests {
    private let viewModel = MasjidDetailViewModel(
        masjid: Fixtures.masjid(isVerified: true),
        distanceMeters: nil,
        repository: MockMasjidRepository(),
        calculator: MockPrayerTimeCalculator(result: .success(Fixtures.times(on: "2026-10-21")))
    )

    @Test func onlyTodaysNextPrayerIsHighlighted() {
        let dhuhr = UpcomingPrayer(prayer: .dhuhr, adhan: Date(), iqamah: nil, isTomorrow: false)
        let tomorrowsFajr = UpcomingPrayer(prayer: .fajr, adhan: Date(), iqamah: nil, isTomorrow: true)

        #expect(viewModel.isNext(.dhuhr, upcoming: dhuhr))
        #expect(!viewModel.isNext(.asr, upcoming: dhuhr))
        #expect(!viewModel.isNext(.fajr, upcoming: tomorrowsFajr))
        #expect(!viewModel.isNext(.fajr, upcoming: nil))
    }

    @Test func calculatedDaysExplainThemselves() {
        #expect(viewModel.todayFooter(for: Fixtures.times(on: "2026-10-21")).hasPrefix("This masjid hasn't published"))
        #expect(viewModel.todayFooter(for: Fixtures.times(on: "2026-10-21", source: .manual))
            == "Times are in America/Los_Angeles.")
    }
}
