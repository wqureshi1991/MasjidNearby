import SwiftUI

struct SignUpView: View {
    @State private var viewModel: SignUpViewModel

    init(viewModel: SignUpViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $viewModel.email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $viewModel.password)
                    .textContentType(.newPassword)
                SecureField("Confirm password", text: $viewModel.confirmPassword)
                    .textContentType(.newPassword)
            } footer: {
                if let message = viewModel.validationMessage {
                    Text(message)
                        .foregroundStyle(.red)
                } else if let error = viewModel.state.error {
                    Text(error.localizedDescription)
                        .foregroundStyle(.red)
                } else if viewModel.role == .masjidAdmin {
                    Text("After signing up you'll add your masjid's details. New masjids are reviewed before they appear to users.")
                }
            }

            Section {
                Button {
                    Task { await viewModel.signUp() }
                } label: {
                    HStack {
                        Text("Create Account")
                        Spacer()
                        if viewModel.state.isLoading {
                            ProgressView()
                        }
                    }
                }
                .disabled(!viewModel.canSubmit)
            }
        }
        .navigationTitle(viewModel.title)
        .onSubmit {
            Task { await viewModel.signUp() }
        }
    }
}
