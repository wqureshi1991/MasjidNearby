import SwiftUI

struct SignInView: View {
    @State private var viewModel: SignInViewModel

    init(viewModel: SignInViewModel) {
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
                    .textContentType(.password)
            } footer: {
                if let error = viewModel.state.error {
                    Text(error.localizedDescription)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    Task { await viewModel.signIn() }
                } label: {
                    HStack {
                        Text("Sign In")
                        Spacer()
                        if viewModel.state.isLoading {
                            ProgressView()
                        }
                    }
                }
                .disabled(!viewModel.canSubmit)

                Button("Forgot password?") {
                    viewModel.forgotPassword()
                }
            }

            Section {
                Button("Create an account") {
                    viewModel.createAccount()
                }
            }
        }
        .navigationTitle(viewModel.title)
        .onSubmit {
            Task { await viewModel.signIn() }
        }
    }
}
