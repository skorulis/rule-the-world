import Foundation
import Testing
import os
@testable import RuleTheWorld

@MainActor
struct PowerUpRendererTests {
    private func effect() -> PowerUpEffect {
        PowerUpEffect(
            id: UUID(), type: .defend, rarity: .rare, bonus: 2,
            cells: [HexCell(rawValue: 0x8a2830828767fff)], startedAt: .now
        )
    }

    @Test func teardownClearsEffectsAndFlipState() {
        let renderer = HexGridOverlayRenderer(overlay: HexGridOverlay(), grid: HexGridService())
        renderer.updatePresentation(effect: effect().confirmed(), reduceMotion: false, animationsEnabled: true)
        #expect(renderer.state.withLock { $0.powerUps.needsAnimation })
        renderer.stopAnimations()
        #expect(renderer.state.withLock { $0.powerUps.effects.isEmpty })
        #expect(renderer.state.withLock { !$0.animationsEnabled && $0.animationStart == 0 })
    }

    @Test func displayLinkDoesNotRetainRenderer() {
        var renderer: HexGridOverlayRenderer? = HexGridOverlayRenderer(
            overlay: HexGridOverlay(), grid: HexGridService()
        )
        weak var released = renderer
        renderer?.updatePresentation(effect: effect().confirmed(), reduceMotion: false, animationsEnabled: true)
        renderer = nil
        #expect(released == nil)
    }

    @Test func reducedMotionSkipsOwnershipFlipButKeepsEffect() {
        let renderer = HexGridOverlayRenderer(overlay: HexGridOverlay(), grid: HexGridService())
        let cell = HexCell(rawValue: 0x8a2830828767fff)
        renderer.update(snapshot: HexOwnershipSnapshot(states: [:]), mode: .territory)
        renderer.updatePresentation(effect: effect().confirmed(), reduceMotion: true, animationsEnabled: true)
        renderer.update(snapshot: HexOwnershipSnapshot(states: [cell: .owned]), mode: .territory)
        #expect(renderer.state.withLock { $0.animationStart == 0 })
        #expect(renderer.state.withLock { $0.reduceMotion && $0.powerUps.needsAnimation })
        renderer.stopAnimations()
    }
}
