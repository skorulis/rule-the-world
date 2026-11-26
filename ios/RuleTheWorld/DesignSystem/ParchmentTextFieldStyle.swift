import SwiftUI

struct ParchmentTextFieldStyle: TextFieldStyle {
    var symbol: String?

    // swiftlint:disable:next identifier_name
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration.modifier(ParchmentFieldModifier(symbol: symbol))
    }
}

private struct ParchmentFieldModifier: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var isFocused: Bool
    let symbol: String?

    private let ink = Color(red: 0.3, green: 0.18, blue: 0.11)
    private let bronze = Color(red: 0.55, green: 0.37, blue: 0.2)

    func body(content: Content) -> some View {
        HStack(spacing: 10) {
            if let symbol {
                GameSymbol(symbol)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
                    .onTapGesture { isFocused = true }
            }
            content
                .font(.body)
                .foregroundStyle(ink)
                .tint(ink)
                .focused($isFocused)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 48)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.88, green: 0.76, blue: 0.54),
                        Color(red: 1, green: 0.94, blue: 0.77),
                    ],
                    startPoint: .top, endPoint: .bottom
                ))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(ink.opacity(0.2), lineWidth: 3)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isFocused ? bronze : ink.opacity(0.6), lineWidth: isFocused ? 2 : 1)
                }
                .shadow(color: .white.opacity(0.35), radius: 0, y: 1)
                .allowsHitTesting(false)
        }
        .opacity(isEnabled ? 1 : 0.5)
    }
}

#Preview {
    @Previewable @State var email = ""
    @Previewable @State var password = ""

    ParchmentPanel {
        VStack(spacing: 12) {
            TextField("Email", text: $email, prompt: Text("Email").foregroundStyle(.brown))
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("Password", text: $password, prompt: Text("Password").foregroundStyle(.brown))
            TextField("Disabled", text: .constant("Unavailable"))
                .disabled(true)
        }
        .textFieldStyle(ParchmentTextFieldStyle())
    }
    .padding(24)
}
