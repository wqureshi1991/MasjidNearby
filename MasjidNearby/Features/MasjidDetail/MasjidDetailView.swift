import SwiftUI

struct MasjidDetailView: View {
    @State private var viewModel: MasjidDetailViewModel
    /// Advanced every 30 seconds so "next prayer" moves on by itself.
    @State private var now = Date()

    init(viewModel: MasjidDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            MasjidDetailHeaderSection(viewModel: viewModel)
            switch viewModel.state {
            case .idle, .loading:
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            case .failed(let error):
                Section {
                    Text(error.localizedDescription)
                        .foregroundStyle(.red)
                    Button("Try Again") {
                        Task { await viewModel.load() }
                    }
                }
            case .loaded(let schedule):
                if let upcoming = viewModel.upcoming(at: now) {
                    NextPrayerSection(upcoming: upcoming, viewModel: viewModel)
                }
                TodayScheduleSection(today: schedule.today, upcoming: viewModel.upcoming(at: now), viewModel: viewModel)
                if !viewModel.masjid.jumuah.isEmpty {
                    JumuahSection(viewModel: viewModel)
                }
            }
        }
        .navigationTitle(viewModel.masjid.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.canFavorite {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.isFavorite ? "Remove from favorites" : "Add to favorites",
                           systemImage: viewModel.isFavorite ? "star.fill" : "star") {
                        Task { await viewModel.toggleFavorite() }
                    }
                    .labelStyle(.iconOnly)
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .task {
            await advanceClock()
        }
        .refreshable {
            await viewModel.load()
        }
    }

    // MARK: - Helpers

    private func advanceClock() async {
        while !Task.isCancelled {
            now = Date()
            do {
                try await Task.sleep(for: .seconds(30))
            } catch {
                return
            }
        }
    }
}
