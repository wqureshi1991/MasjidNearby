import SwiftUI

struct FavoritesView: View {
    let viewModel: FavoritesViewModel
    /// Advanced every 30 seconds so each row's next prayer moves on.
    @State private var now = Date()

    var body: some View {
        FavoritesContent(viewModel: viewModel, now: now)
            .navigationTitle("Favorites")
            .task {
                await viewModel.load()
                await viewModel.refresh()
            }
            .task {
                await advanceClock()
            }
    }

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
