import SwiftUI

/// First-launch slideshow introducing the game, shown before sign in.
/// Backgrounds are hand-authored SVGs in ios/Icons, rasterized into the asset catalog.
struct OnboardingView: View {
    @State var model: OnboardingViewModel
    let onFinish: () -> Void

    var body: some View {
        ZStack {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(model.pages) { page in
                        pageView(page)
                            .containerRelativeFrame(.horizontal)
                            .id(page.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: scrolledPage)
            .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button("Skip", action: onFinish)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                }
                .padding(.horizontal, 24)

                Spacer()

                Button {
                    if model.isLastPage {
                        onFinish()
                    } else {
                        model.advance()
                    }
                } label: {
                    Text(model.buttonTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.orange)
                .padding(.horizontal, 32)

                pageIndicator
                    .padding(.top, 20)
            }
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
    }

    private var scrolledPage: Binding<Int?> {
        Binding(
            get: { model.currentPage },
            set: { model.currentPage = $0 ?? 0 }
        )
    }

    private var pageIndicator: some View {
        HStack(spacing: 10) {
            ForEach(model.pages) { page in
                Circle()
                    .fill(page.id == model.currentPage ? Color.white : Color.white.opacity(0.45))
                    .frame(width: 10, height: 10)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            }
        }
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        ZStack {
            Image(page.imageName)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack {
                LinearGradient(
                    colors: [.black.opacity(0.65), .black.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 380)
                Spacer()
            }
            .ignoresSafeArea()

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                Text(page.subtitle)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                    .padding(.horizontal, 32)
                Spacer()
            }
            .padding(.top, 110)
        }
    }
}

#Preview {
    OnboardingView(model: OnboardingViewModel()) {}
}
