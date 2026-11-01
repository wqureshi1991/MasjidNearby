import SwiftUI

struct WelcomeView: View {
    /// `@State` keeps the first ViewModel; later ones built by parent re-renders are discarded.
    @State private var viewModel: WelcomeViewModel

    init(viewModel: WelcomeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "building.columns")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Masjid Nearby")
                .font(.largeTitle.bold())
            Text("Prayer times from masjids near you.")
                .foregroundStyle(.secondary)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task { await viewModel.continueAsGuest() }
                } label: {
                    Group {
                        if viewModel.guestState.isLoading {
                            ProgressView()
                        } else {
                            Text("Find Prayer Times")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.guestState.isLoading)

                if let error = viewModel.guestState.error {
                    Text(error.localizedDescription)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    viewModel.signIn(as: .user)
                } label: {
                    Text("Sign In").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button("I manage a masjid") {
                    viewModel.signIn(as: .masjidAdmin)
                }
                .padding(.top, 8)
            }
        }
        .padding()
    }
}
