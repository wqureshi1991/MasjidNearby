import SwiftUI

/// A publish button with its progress, result and blocking problems.
struct PublishDaysSection: View {
    let title: String
    let state: LoadState<Int>
    let canPublish: Bool
    let footer: String?
    let onPublish: @MainActor () async -> Void
    var onDone: (@MainActor () -> Void)?

    var body: some View {
        Section {
            Button {
                Task { await onPublish() }
            } label: {
                HStack {
                    Text(title)
                    Spacer()
                    if state.isLoading {
                        ProgressView()
                    }
                }
            }
            .disabled(!canPublish)

            switch state {
            case .loaded(let count):
                Label("Published \(count) \(count == 1 ? "day" : "days").", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
                if let onDone {
                    Button("Done", action: onDone)
                }
            case .failed(let error):
                Text(error.localizedDescription)
                    .foregroundStyle(.red)
            case .idle, .loading:
                EmptyView()
            }
        } footer: {
            if let footer {
                Text(footer)
            }
        }
    }
}
