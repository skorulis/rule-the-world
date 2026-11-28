import Foundation

nonisolated struct PowerUpEffect: Sendable, Equatable, Identifiable {
    enum Phase: Sendable, Equatable {
        case pending
        case confirmed
    }

    let id: UUID
    let type: PowerUpType
    let rarity: Rarity
    let bonus: Int
    let cells: [HexCell]
    var phase: Phase = .pending
    var startedAt: Date

    static let duration: TimeInterval = 1.25
    static let reducedDuration: TimeInterval = 0.65

    func delay(for index: Int, reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? 0 : min(Double(max(index, 0)) * 0.075, 0.3)
    }

    func progress(for index: Int, at date: Date, reduceMotion: Bool) -> Double {
        let duration = reduceMotion ? Self.reducedDuration : Self.duration
        return (date.timeIntervalSince(startedAt) - delay(for: index, reduceMotion: reduceMotion)) / duration
    }

    func isExpired(at date: Date, reduceMotion: Bool) -> Bool {
        if phase == .pending { return date.timeIntervalSince(startedAt) > 120 }
        return progress(for: max(cells.count - 1, 0), at: date, reduceMotion: reduceMotion) >= 1
    }

    func confirmed(at date: Date = .now) -> Self {
        var result = self
        result.phase = .confirmed
        result.startedAt = date
        return result
    }
}

nonisolated struct PowerUpEffectPlayback: Sendable {
    private(set) var effects: [PowerUpEffect] = []
    private var receipts: [(id: UUID, phase: PowerUpEffect.Phase)] = []

    mutating func update(_ effect: PowerUpEffect?, at date: Date, reduceMotion: Bool, enabled: Bool) {
        prune(at: date, reduceMotion: reduceMotion)
        effects.removeAll { $0.phase == .pending && ($0.id != effect?.id || effect?.phase != .pending) }
        if let effect, !receipts.contains(where: { $0.id == effect.id && $0.phase == effect.phase }) {
            receipts.append((effect.id, effect.phase))
            receipts = Array(receipts.suffix(16))
            if enabled && !effect.isExpired(at: date, reduceMotion: reduceMotion) {
                effects.removeAll { $0.id == effect.id }
                effects.append(effect)
                effects = Array(effects.suffix(4))
            }
        }
        if !enabled { effects = [] }
    }

    mutating func prune(at date: Date, reduceMotion: Bool) {
        effects.removeAll { $0.isExpired(at: date, reduceMotion: reduceMotion) }
    }

    var needsAnimation: Bool { effects.contains { $0.phase == .confirmed } }

    mutating func stop() {
        effects = []
    }
}
