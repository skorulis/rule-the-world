import SwiftUI

struct ParchmentTabView<Tab: Hashable, Content: View>: View {
    let tabs: [Tab]
    @Binding var selection: Tab
    let title: KeyPath<Tab, String>
    @ViewBuilder var content: () -> Content

    private let ink = Color(red: 0.25, green: 0.12, blue: 0.04)

    var body: some View {
        VStack(spacing: -2) {
            ScrollView(.horizontal) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(tabs, id: \.self) { tab in
                        Button {
                            selection = tab
                        } label: {
                            Text(tab[keyPath: title])
                                .font(.system(.headline, design: .serif, weight: .heavy))
                                .foregroundStyle(ink)
                                .padding(.horizontal, 16)
                                .padding(.vertical, selection == tab ? 16 : 11)
                                .background {
                                    UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12)
                                        .fill(LinearGradient(
                                            colors: selection == tab
                                                ? [ParchmentPalette.colors[1], ParchmentPalette.colors[0]]
                                                : [.yellow, .orange],
                                            startPoint: .top, endPoint: .bottom
                                        ))
                                        .overlay {
                                            UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12)
                                                .strokeBorder(ink, lineWidth: 2)
                                        }
                                }
                                .overlay(alignment: .bottom) {
                                    if selection == tab {
                                        Rectangle()
                                            .fill(ParchmentPalette.colors[0])
                                            .frame(height: 4)
                                            .padding(.horizontal, 2)
                                            .offset(y: 1)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selection == tab ? [.isSelected] : [])
                    }
                }
                .padding(.horizontal, 8)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .zIndex(1)
            ParchmentPanel(style: .thin(borderColor: ink)) {
                content()
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

#Preview {
    @Previewable @State var selection = "Pattern"
    ParchmentTabView(tabs: ["Pattern", "Colors", "Emblem"], selection: $selection, title: \.self) {
        Text("Edit \(selection)")
            .frame(height: 160)
    }
    .padding()
    .background(.brown)
}
