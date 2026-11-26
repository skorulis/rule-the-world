import Knit
import SwiftUI

struct LoginView: View {
    @State var model: LoginViewModel

    var body: some View {
        VStack(spacing: 24) {
            title
            formPanel
            Spacer()
        }
        .padding()
        .contentShape(Rectangle())
        .background {
            background
        }
    }

    private var title: some View {
        VStack(spacing: -10) {
            Image("HexOwned")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            DecorativeText("RULE THE", fontSize: 48)
            DecorativeText("WORLD", fontSize: 52)
        }
        .padding(.top, 48)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rule the World")
        .accessibilityAddTraits(.isHeader)
    }

    private var formPanel: some View {
        ParchmentPanel {
            VStack(spacing: 24) {
                inputFields
                errorMessage
                submitButton
                modeToggleButton
            }
        }
        .overlay(alignment: .topTrailing) {
            Image("mascot-half")
                .resizable()
                .scaledToFit()
                .frame(height: 120)
                .padding(.trailing, 8)
                .offset(y: -100)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .padding(.top, 76)
    }

    private var inputFields: some View {
        VStack(spacing: 12) {
            if model.isSignUpMode {
                TextField("Name", text: $model.name, prompt: fieldPrompt("Name"))
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .textFieldStyle(ParchmentTextFieldStyle(symbol: "person.fill"))
            }

            TextField("Email", text: $model.email, prompt: fieldPrompt("Email"))
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(ParchmentTextFieldStyle(symbol: "envelope.fill"))

            SecureField(
                "Password", text: $model.password,
                prompt: fieldPrompt("Password")
            )
            .textContentType(model.isSignUpMode ? .newPassword : .password)
            .textFieldStyle(ParchmentTextFieldStyle(symbol: "key.fill"))
        }
    }

    private func fieldPrompt(_ title: String) -> Text {
        Text(title)
            .fontWeight(.semibold)
            .foregroundStyle(Color(red: 0.35, green: 0.22, blue: 0.13))
    }

    @ViewBuilder
    private var errorMessage: some View {
        if let errorMessage = model.errorMessage {
            Text(errorMessage)
                .font(.callout)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        }
    }

    private var submitButton: some View {
        Button {
            Task { await model.submit() }
        } label: {
            if model.isLoading {
                ProgressView()
            } else {
                Text(model.submitTitle)
            }
        }
        .buttonStyle(GoldButtonStyle(fillsWidth: true))
        .disabled(!model.canSubmit || model.isLoading)
    }

    private var modeToggleButton: some View {
        Button(model.modeToggleTitle) {
            model.toggleMode()
        }
        .buttonStyle(ParchmentButtonStyle())
    }

    private var background: some View {
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

#Preview {
    let assembler = RuleTheWorldAssembly.testing()
    LoginView(model: assembler.resolver.loginViewModel())
}
