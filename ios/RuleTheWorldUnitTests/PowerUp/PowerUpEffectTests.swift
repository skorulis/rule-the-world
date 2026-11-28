import Foundation
import Testing
@testable import RuleTheWorld

struct PowerUpEffectTests {
    private let now = Date(timeIntervalSince1970: 1_000)

    private func effect(count: Int = 5) -> PowerUpEffect {
        PowerUpEffect(
            id: UUID(), type: .explore, rarity: .rare, bonus: 2,
            cells: Array(repeating: HexCell(rawValue: 0x8a2830828767fff), count: count),
            startedAt: now
        )
    }

    @Test func confirmationPreservesUseAndExactTargets() {
        let pending = effect()
        let confirmed = pending.confirmed(at: now.addingTimeInterval(1))
        #expect(confirmed.id == pending.id)
        #expect(confirmed.cells == pending.cells)
        #expect(confirmed.type == .explore)
        #expect(confirmed.bonus == 2)
        #expect(confirmed.phase == .confirmed)
        #expect(confirmed.startedAt == now.addingTimeInterval(1))
    }

    @Test func staggerIsDeterministicAndCapped() {
        let effect = effect(count: 100)
        #expect(effect.delay(for: 0, reduceMotion: false) == 0)
        #expect(effect.delay(for: 1, reduceMotion: false) == 0.075)
        #expect(effect.delay(for: 99, reduceMotion: false) == 0.3)
        #expect(effect.delay(for: 99, reduceMotion: true) == 0)
    }

    @Test func progressAndExpiryIncludeLastTarget() {
        let effect = effect().confirmed(at: now)
        #expect(effect.progress(for: 1, at: now, reduceMotion: false) < 0)
        #expect(!effect.isExpired(at: now.addingTimeInterval(1.3), reduceMotion: false))
        #expect(effect.isExpired(at: now.addingTimeInterval(1.6), reduceMotion: false))
        #expect(effect.isExpired(at: now.addingTimeInterval(0.7), reduceMotion: true))
    }

    @Test func pendingTargetsDoNotNeedAnimationAndClearOnFailure() {
        var playback = PowerUpEffectPlayback()
        playback.update(effect(), at: now, reduceMotion: false, enabled: true)
        #expect(playback.effects.count == 1)
        #expect(!playback.needsAnimation)
        playback.update(nil, at: now, reduceMotion: false, enabled: true)
        #expect(playback.effects.isEmpty)
    }

    @Test func confirmationReplacesSealAndDoesNotRestartOnRedraw() {
        var playback = PowerUpEffectPlayback()
        let pending = effect()
        playback.update(pending, at: now, reduceMotion: false, enabled: true)
        let confirmed = pending.confirmed(at: now)
        playback.update(confirmed, at: now, reduceMotion: false, enabled: true)
        playback.update(confirmed, at: now.addingTimeInterval(0.5), reduceMotion: false, enabled: true)
        #expect(playback.effects == [confirmed])
        #expect(playback.needsAnimation)
        playback.prune(at: now.addingTimeInterval(2), reduceMotion: false)
        playback.update(confirmed, at: now.addingTimeInterval(2), reduceMotion: false, enabled: true)
        #expect(playback.effects.isEmpty)
    }

    @Test func coalescedConfirmationAndOverlapsAreSupportedButBounded() {
        var playback = PowerUpEffectPlayback()
        for _ in 0..<10 {
            playback.update(effect().confirmed(at: now), at: now, reduceMotion: false, enabled: true)
        }
        #expect(playback.effects.count == 4)
        playback.prune(at: now.addingTimeInterval(2), reduceMotion: false)
        #expect(playback.effects.isEmpty)
    }

    @Test func staleEventsDoNotReplayOnRendererRecreation() {
        var playback = PowerUpEffectPlayback()
        let old = effect().confirmed(at: now.addingTimeInterval(-10))
        playback.update(old, at: now, reduceMotion: false, enabled: true)
        #expect(playback.effects.isEmpty)
    }

    @Test func backgroundAndTeardownDiscardEffectsWithoutReplaying() {
        var playback = PowerUpEffectPlayback()
        let effect = effect().confirmed(at: now)
        playback.update(effect, at: now, reduceMotion: false, enabled: true)
        playback.update(effect, at: now, reduceMotion: false, enabled: false)
        #expect(playback.effects.isEmpty)
        playback.update(effect, at: now, reduceMotion: false, enabled: true)
        #expect(playback.effects.isEmpty)
        let next = self.effect().confirmed(at: now)
        playback.update(next, at: now, reduceMotion: true, enabled: true)
        #expect(playback.effects.count == 1)
        playback.stop()
        playback.update(next, at: now, reduceMotion: true, enabled: true)
        #expect(playback.effects.isEmpty)
    }

    @Test func pendingTimeoutIsBounded() {
        let pending = effect()
        #expect(!pending.isExpired(at: now.addingTimeInterval(5), reduceMotion: false))
        #expect(pending.isExpired(at: now.addingTimeInterval(121), reduceMotion: false))
    }
}
