import SwiftUI

struct AdminHomeView: View {
    let viewModel: AdminHomeViewModel

    var body: some View {
        List {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
            case .failed(let error):
                Section {
                    Text(error.localizedDescription)
                        .foregroundStyle(.red)
                    Button("Try Again") {
                        Task { await viewModel.load() }
                    }
                }
            case .loaded(.none):
                Section {
                    Text("Register your masjid to publish its prayer times.")
                    Button("Register Masjid") {
                        viewModel.registerMasjid()
                    }
                }
            case .loaded(.some(let masjid)):
                Section("Masjid") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(masjid.name)
                            .font(.headline)
                        Text(masjid.address)
                            .foregroundStyle(.secondary)
                    }
                    if masjid.isVerified {
                        Label("Verified", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Awaiting review. Users will see your masjid once it's approved.", systemImage: "clock")
                            .foregroundStyle(.orange)
                    }
                }
                Section {
                    Button("Edit Prayer Times") {
                        viewModel.editSchedule()
                    }
                    Button("Edit Masjid Details") {
                        viewModel.editDetails()
                    }
                }
            }
        }
        .navigationTitle("My Masjid")
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load()
        }
    }
}
