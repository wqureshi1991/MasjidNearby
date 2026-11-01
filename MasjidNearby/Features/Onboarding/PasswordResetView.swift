import SwiftUI

struct PasswordResetView: View {
    @State private var viewModel: PasswordResetViewModel

    init(viewModel: PasswordResetViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Form {
            if viewModel.state.isLoaded {
                Section {
                    Label("Check your email", systemImage: "envelope")
                        .font(.headline)
                    Text("If an account exists for \(viewModel.email), we've sent a link to reset its password.")
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button("Done") {
                        viewModel.done()
                    }
                }
            } else {
                Section {
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    if let error = viewModel.state.error {
                        Text(error.localizedDescription)
                            .foregroundStyle(.red)
                    } else {
                        Text("We'll email you a link to choose a new password.")
                    }
                }
                Section {
                    Button {
                        Task { await viewModel.sendReset() }
                    } label: {
                        HStack {
                            Text("Send Reset Link")
                            Spacer()
                            if viewModel.state.isLoading {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(!viewModel.canSubmit)
                }
            }
        }
        .navigationTitle("Reset Password")
        .onSubmit {
            Task { await viewModel.sendReset() }
        }
    }
}
