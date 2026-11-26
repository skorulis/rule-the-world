import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct ProfileSummaryStoreTests {
    private func makeStore() -> (ProfileSummaryStore, PKeyValueStore) {
        let keyValueStore: PKeyValueStore = InMemoryKeyValueStore()
        return (ProfileSummaryStore(keyValueStore: keyValueStore), keyValueStore)
    }

    private func summary(_ json: String) throws -> ProfileSummary {
        try JSONDecoder().decode(ProfileSummary.self, from: Data(json.utf8))
    }

    @Test func savedSummaryRoundTrips() throws {
        let (store, _) = makeStore()
        store.save(try summary(#"{"visited":25,"owned":8,"rankings":[{"id":1,"type":"country","number":2}]}"#))
        let summary = store.summary
        #expect(summary?.visited == 25)
        #expect(summary?.owned == 8)
        #expect(summary?.rankings.count == 1)
    }

    @Test func savedSummaryPreservesAccountIdentity() throws {
        let (store, _) = makeStore()
        store.save(try summary(#"{"user":{"id":"alice","name":"Alice"}}"#))
        #expect(store.summary?.userID == "alice")
        #expect(store.summary?.userName == "Alice")
    }

    @Test func legacyAndBlankIdentityRemainCompatible() throws {
        for json in [#"{}"#, #"{"user":{"name":"Legacy"}}"#, #"{"user":{"id":" "}}"#] {
            let (store, _) = makeStore()
            store.save(try summary(json))
            #expect(store.summary != nil)
            #expect(store.summary?.userID == nil)
        }
    }

    @Test func savedSummaryPreservesDates() throws {
        let (store, _) = makeStore()
        let original = try summary(#"{"dailyRewardAvailableAt":"2026-11-24T00:00:00.000Z"}"#)
        store.save(original)
        #expect(store.summary?.dailyRewardAvailableAt == Date(timeIntervalSince1970: 1_795_478_400))
    }

    @Test func undecodableBlobReturnsNil() {
        let (store, keyValueStore) = makeStore()
        keyValueStore.set(Data("not json".utf8), forKey: ProfileSummaryStore.key)
        #expect(store.summary == nil)
    }

    @Test func missingBlobReturnsNil() {
        let (store, _) = makeStore()
        #expect(store.summary == nil)
    }

    @Test func updateRankingsReplacesOnlyTheRankingsField() throws {
        let (store, _) = makeStore()
        store.save(try summary(#"{"visited":25,"owned":8,"rankings":[{"id":1,"type":"country","number":2}]}"#))
        store.update(rankings: [
            ProfileSummary.Ranking(id: 7, type: "suburb", number: 1, visited: 5, owned: 3)
        ])
        let summary = try #require(store.summary)
        #expect(summary.visited == 25)
        #expect(summary.owned == 8)
        #expect(summary.rankings.count == 1)
        #expect(summary.rankings[0].id == 7)
        #expect(summary.rankings[0].type == "suburb")
        #expect(summary.rankings[0].number == 1)
        #expect(summary.rankings[0].visited == 5)
        #expect(summary.rankings[0].owned == 3)
    }

    @Test func updateRankingsClearsStoredRankingsWhenEmpty() throws {
        let (store, _) = makeStore()
        store.save(try summary(#"{"visited":25,"rankings":[{"id":1,"type":"country","number":2}]}"#))
        store.update(rankings: [])
        #expect(try #require(store.summary).rankings.isEmpty)
    }

    @Test func updateRankingsDoesNothingWithoutStoredSummary() {
        let (store, _) = makeStore()
        store.update(rankings: [ProfileSummary.Ranking(id: 1, type: "global", number: 1, visited: nil, owned: nil)])
        #expect(store.summary == nil)
    }

    @Test func updateRankingsDoesNothingWithUndecodableBlob() {
        let (store, keyValueStore) = makeStore()
        keyValueStore.set(Data("not json".utf8), forKey: ProfileSummaryStore.key)
        store.update(rankings: [ProfileSummary.Ranking(id: 1, type: "global", number: 1, visited: nil, owned: nil)])
        #expect(store.summary == nil)
    }

    @Test func clearRemovesTheBlob() throws {
        let (store, _) = makeStore()
        store.save(try summary(#"{"visited":25}"#))
        store.clear()
        #expect(store.summary == nil)
    }
}
