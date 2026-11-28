import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

extension PowerUpInventoryViewModelTests {
    @Test func mapEffectUsesExactRequestedTargetsAndStableUseID() async throws {
        let store = try makeStore()
        try await seedStore(store)
        var inventory: PowerUpInventoryViewModel?
        var pending: PowerUpEffect?
        var requested: [String] = []
        let model = try makeModel(
            body: #"{"powerups":{"1":1}}"#, store: store,
            onConsumeRequest: { request in
                pending = inventory?.mapEffect
                requested = (try? self.sentCells(request)) ?? []
            }
        )
        inventory = model
        defer { inventory = nil }
        await model.load()
        await model.consume(item: try #require(model.items.first))
        let preparing = try #require(pending)
        let confirmed = try #require(model.mapEffect)
        #expect(preparing.phase == .pending)
        #expect(confirmed.phase == .confirmed)
        #expect(preparing.id == confirmed.id)
        #expect(preparing.cells == confirmed.cells)
        #expect(Set(confirmed.cells.map(\.description)) == Set(requested))
        #expect(confirmed.type == .attack)
        #expect(confirmed.rarity == .common)
        #expect(confirmed.bonus == 1)
        #expect(model.items.isEmpty)
    }

    @Test func pendingEffectIsClearedAfterRequestFailure() async throws {
        let store = try makeStore()
        try await seedStore(store)
        var inventory: PowerUpInventoryViewModel?
        var pending: PowerUpEffect?
        let model = try makeModel(
            body: #"{"powerups":{"3":1}}"#, store: store,
            consumeStatus: 500, consumeBody: #"{"error":"Rejected"}"#,
            onConsumeRequest: { _ in pending = inventory?.mapEffect }
        )
        inventory = model
        defer { inventory = nil }
        await model.load()
        await model.consume(item: try #require(model.items.first))
        #expect(pending?.type == .defend)
        #expect(pending?.phase == .pending)
        #expect(model.mapEffect == nil)
        #expect(model.items.first?.count == 1)
    }

    @Test func cancellationDoesNotCelebratePendingUse() async throws {
        let store = try makeStore()
        try await seedStore(store)
        var task: Task<Void, Never>?
        let model = try makeModel(
            body: #"{"powerups":{"5":1}}"#, store: store,
            onConsumeRequest: { _ in task?.cancel() }
        )
        defer { task = nil }
        await model.load()
        let item = try #require(model.items.first)
        task = Task { await model.consume(item: item) }
        await task?.value
        #expect(model.mapEffect == nil)
        #expect(model.activatedItemID == nil)
        #expect(!model.isConsuming)
    }

    @Test func leavingMapMidRequestDoesNotReplayEffectOnReturn() async throws {
        let store = try makeStore()
        try await seedStore(store)
        var inventory: PowerUpInventoryViewModel?
        let model = try makeModel(
            body: #"{"powerups":{"5":1}}"#, store: store,
            onConsumeRequest: { _ in
                inventory?.setMapEffectsVisible(false)
                inventory?.setMapEffectsVisible(true)
            }
        )
        inventory = model
        defer { inventory = nil }
        await model.load()
        await model.consume(item: try #require(model.items.first))
        #expect(model.mapEffect == nil)
        #expect(model.items.isEmpty)
        #expect(model.activatedItemID == 5)
    }
}
