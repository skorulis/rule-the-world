import SwiftUI

struct LoginView: View {
    @State var model: LoginViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Rule the World")
                .font(.largeTitle.bold())

            VStack(spacing: 12) {
                if model.isSignUpMode {
                    TextField("Name", text: $model.name)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }

                TextField("Email", text: $model.email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Password", text: $model.password)
                    .textContentType(model.isSignUpMode ? .newPassword : .password)
            }
            .textFieldStyle(.roundedBorder)

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await model.submit() }
            } label: {
                if model.isLoading {
                    ProgressView()
                } else {
                    Text(model.submitTitle)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!model.canSubmit || model.isLoading)

            Button(model.modeToggleTitle) {
                model.toggleMode()
            }
            .font(.callout)

            Spacer()
        }
        .padding()
        .contentShape(Rectangle())
    }
}
