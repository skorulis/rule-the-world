import ASKCoordinator
import SwiftUI

struct StandardListLayout<Content: View, HeaderActions: View>: View {
    @Environment(\.coordinator) private var coordinator
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 32

    private let title: String
    private let content: Content
    private let headerActions: HeaderActions
    private let scrollTarget: (any Hashable)?

    init(
        _ title: String,
        scrollTarget: (any Hashable)? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder headerActions: () -> HeaderActions
    ) {
        self.title = title
        self.scrollTarget = scrollTarget
        self.content = content()
        self.headerActions = headerActions()
    }

    init(
        _ title: String,
        scrollTarget: (any Hashable)? = nil,
        @ViewBuilder content: () -> Content
    ) where HeaderActions == EmptyView {
        self.init(title, scrollTarget: scrollTarget, content: content, headerActions: { EmptyView() })
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            WoodenDivider()
            ScrollViewReader { proxy in
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
                .environment(\.colorScheme, .light)
                .onAppear {
                    if let scrollTarget {
                        proxy.scrollTo(scrollTarget, anchor: .center)
                    }
                }
            }
        }
        .background {
            LinearGradient(
                colors: [
                    Color(red: 0.3, green: 0.19, blue: 0.15),
                    Color(red: 0.2, green: 0.12, blue: 0.13)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .tint(Color(red: 1, green: 0.9, blue: 0.7))
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Group {
                if coordinator?.canPop == true {
                    Button("Back", systemImage: "chevron.backward") {
                        coordinator?.pop()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(BackButtonStyle())
                } else {
                    Color.clear
                        .frame(width: 56, height: 56)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: 56)

            Text(title)
                .font(.system(size: titleSize, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 1, green: 0.96, blue: 0.84))
                .shadow(color: Color(red: 0.08, green: 0.06, blue: 0.1), radius: 1, y: 2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)

            ZStack {
                Color.clear
                headerActions
            }
            .frame(width: 56, height: 56)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(minHeight: 104)
        .background {
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.18, blue: 0.38),
                    Color(red: 0.16, green: 0.32, blue: 0.57),
                    Color(red: 0.16, green: 0.53, blue: 0.68)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(.container, edges: .top)
            .overlay { headerStars }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private var headerStars: some View {
        GeometryReader { geometry in
            ZStack {
                TwinkleStar(shape: .circle, size: 5, duration: 2.8)
                    .position(x: geometry.size.width * 0.18, y: geometry.size.height * 0.16)
                TwinkleStar(size: 10, duration: 3.2)
                    .position(x: geometry.size.width * 0.29, y: geometry.size.height * 0.25)
                TwinkleStar(shape: .circle, size: 6, duration: 2.2)
                    .position(x: geometry.size.width * 0.4, y: geometry.size.height * 0.82)
                TwinkleStar(shape: .circle, size: 4, duration: 3.5)
                    .position(x: geometry.size.width * 0.54, y: geometry.size.height * 0.12)
                TwinkleStar(size: 8, duration: 2.6)
                    .position(x: geometry.size.width * 0.68, y: geometry.size.height * 0.14)
                TwinkleStar(size: 13, duration: 3)
                    .position(x: geometry.size.width * 0.77, y: geometry.size.height * 0.78)
                TwinkleStar(shape: .circle, size: 6, duration: 2.4)
                    .position(x: geometry.size.width * 0.92, y: geometry.size.height * 0.2)
                TwinkleStar(shape: .circle, size: 5, duration: 3.4)
                    .position(x: geometry.size.width * 0.08, y: geometry.size.height * 0.86)
            }
        }
        .clipped()
    }
}

private enum StandardListPreviewPath: String, CoordinatorPath {
    case root
    case profile

    var id: String { rawValue }
}

private struct StandardListPreviewRenderer: CoordinatorPathRenderer {
    typealias PathType = StandardListPreviewPath

    @MainActor
    func render(path: StandardListPreviewPath, in coordinator: Coordinator) -> some View {
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

#Preview {
    let coordinator = Coordinator(root: StandardListPreviewPath.root)
    coordinator.push(StandardListPreviewPath.profile)
    return CoordinatorView(coordinator: coordinator)
        .with(renderer: StandardListPreviewRenderer())
}

#Preview("Large text") {
    StandardListLayout("Profile") {
        LabeledContent("Name", value: "Explorer")
    }
    .environment(\.dynamicTypeSize, .accessibility1)
}
