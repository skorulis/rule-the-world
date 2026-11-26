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
            .listRowBackground(
                LinearGradient(colors: ParchmentPalette.colors, startPoint: .top, endPoint: .bottom)
            )
            .tint(Color(red: 0.3, green: 0.15, blue: 0.08))
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background {
            LinearGradient(
                colors: [
                    Color(red: 0.3, green: 0.19, blue: 0.15),
                    Color(red: 0.2, green: 0.12, blue: 0.13),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .navigationTitle(title)
        .toolbarBackground(Color(red: 0.3, green: 0.19, blue: 0.15), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(Color(red: 1, green: 0.9, blue: 0.7))
        .preferredColorScheme(.light)
    }
}

#Preview {
    NavigationStack {
        StandardListLayout("Profile") {
            Section {
                LabeledContent("Name", value: "Explorer")
            }
            Section {
                Button("Claim reward") {}
            } header: {
                Text("Daily reward")
                    .foregroundStyle(Color(red: 1, green: 0.9, blue: 0.7))
            }
            Section {
                HStack(spacing: 12) {
                    SquareCell(title: "Shop", icon: "Shop", value: 1_086)
                    SquareCell(title: "Titles", icon: "HexOwned", value: 5)
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
    }
}
