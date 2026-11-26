import SwiftUI

struct StandardListLayout<Content: View>: View {
    private let title: LocalizedStringKey
    private let content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        List {
            Group {
                content
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background {
            LinearGradient(colors: ParchmentPalette.colors, startPoint: .top, endPoint: .bottom)
                .overlay {
                    RadialGradient(
                        colors: [Color(red: 1, green: 0.94, blue: 0.75).opacity(0.75), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 600
                    )
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .navigationTitle(title)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(.light)
    }
}

#Preview {
    NavigationStack {
        StandardListLayout("Profile") {
            Section {
                LabeledContent("Name", value: "Explorer")
            }
            Section("Daily reward") {
                Button("Claim reward") {}
            }
        }
    }
}
