import Knit
import SwiftUI

struct LoginView: View {
    @State var model: LoginViewModel

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: -10) {
                DecorativeText("RULE THE", fontSize: 48)
                DecorativeText("WORLD", fontSize: 52)
            }
            .padding(.top, 48)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Rule the World")
            .accessibilityAddTraits(.isHeader)

            Spacer()

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
        .background {
            GeometryReader { geometry in
                Image("LoginBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .accessibilityHidden(true)
            }
            .ignoresSafeArea()
        }
    }
}

#Preview {
    let assembler = RuleTheWorldAssembly.testing()
    LoginView(model: assembler.resolver.loginViewModel())
}
