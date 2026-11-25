import SwiftUI

enum RewardRevealPhase {
    case opening
    case revealed
}

/// Full-screen reward ceremony. The `opening` phase loops a pulsing,
/// wiggling container so the animation starts the moment the user taps and
/// masks the server round trip; `revealed` springs the reward card in over
/// an accent-colored glow with a confetti burst.
struct RewardRevealView<Card: View>: View {
    let phase: RewardRevealPhase
    let accent: Color
    let boxSymbol: String
    var onDone: () -> Void
    @ViewBuilder var card: () -> Card

    init(
        phase: RewardRevealPhase,
        accent: Color,
        boxSymbol: String,
        onDone: @escaping () -> Void,
        @ViewBuilder card: @escaping () -> Card
    ) {
        self.phase = phase
        self.accent = accent
        self.boxSymbol = boxSymbol
        self.onDone = onDone
        self.card = card
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accent.opacity(0.35), .clear],
                        center: .center, startRadius: 0, endRadius: 300
                    )
                )
                .frame(width: 600, height: 600)
            switch phase {
            case .opening:
                OpeningCrate(accent: accent, symbol: boxSymbol)
                    .transition(.opacity)
            case .revealed:
                RevealedReward(accent: accent, onDone: onDone, card: card)
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .interactiveDismissDisabled(phase == .opening)
        .sensoryFeedback(.success, trigger: phase) { $1 == .revealed }
    }
}

/// Pulsing container shown while the reward request is in flight.
private struct OpeningCrate: View {
    let accent: Color
    let symbol: String
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [accent.opacity(0.5), .clear],
                            center: .center, startRadius: 20, endRadius: 130
                        )
                    )
                    .frame(width: 260, height: 260)
                    .scaleEffect(pulse ? 1.1 : 0.9)
                Image(systemName: symbol)
                    .font(.system(size: 96))
                    .foregroundStyle(accent.gradient)
                    .rotationEffect(.degrees(pulse ? -5 : 5))
                    .scaleEffect(pulse ? 1.08 : 0.92)
            }
            Text("Opening…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct RevealedReward<Card: View>: View {
    let accent: Color
    var onDone: () -> Void
    @ViewBuilder var card: () -> Card
    @State private var show = false

    var body: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [accent.opacity(0.55), .clear],
                            center: .center, startRadius: 20, endRadius: 160
                        )
                    )
                    .frame(width: 320, height: 320)
                    .scaleEffect(show ? 1 : 0.3)
                    .opacity(show ? 1 : 0)
                ConfettiBurst(accent: accent)
                card()
                    .scaleEffect(show ? 1 : 0.3)
                    .rotationEffect(.degrees(show ? 0 : -12))
                    .opacity(show ? 1 : 0)
            }
            Button("Collect", action: onDone)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(accent)
                .opacity(show ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                show = true
            }
        }
    }
}

/// A one-shot ring of particles flying outward from the reward.
private struct ConfettiBurst: View {
    let accent: Color
    @State private var burst = false

    private static let colors: [Color] = [.white, .yellow, .orange, .pink, .mint]

    var body: some View {
        ZStack {
            ForEach(0..<20, id: \.self) { index in
                let angle = Double(index) * (2 * .pi / 20) + Double(index % 4) * 0.2
                Capsule()
                    .fill(index.isMultiple(of: 3) ? accent : Self.colors[index % Self.colors.count])
                    .frame(width: 5, height: 9)
                    .rotationEffect(.degrees(burst ? Double(index * 47 % 360) : 0))
                    .offset(
                        x: burst ? cos(angle) * (110 + Double(index * 13 % 40)) : 0,
                        y: burst ? sin(angle) * (110 + Double(index * 13 % 40)) : 0
                    )
                    .opacity(burst ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { burst = true }
        }
    }
}

#Preview("Opening") {
    RewardRevealView(phase: .opening, accent: .gray, boxSymbol: "gift.fill") {} card: {
        EmptyView()
    }
}

#Preview("Revealed") {
    RewardRevealView(phase: .revealed, accent: .blue, boxSymbol: "gift.fill") {} card: {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 64))
            Text("Rare Revisit")
                .font(.title2.bold())
            Text("+2 score")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
