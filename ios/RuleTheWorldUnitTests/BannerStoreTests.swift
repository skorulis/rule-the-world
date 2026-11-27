import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct BannerStoreTests {
    @Test func missingBannerUsesDefault() {
        let store = BannerStore(keyValueStore: InMemoryKeyValueStore())
        #expect(store.banner(for: "alice") == .default)
        #expect(store.banner(for: "") == .default)
    }

    @Test func persistsAcrossInstancesAndIsolatesAccounts() throws {
        let values = InMemoryKeyValueStore()
        let first = BannerStore(keyValueStore: values)
        var banner = BannerConfiguration.default
        banner.emblem = .lion
        try first.save(banner, for: "alice")
        let second = BannerStore(keyValueStore: values)
        #expect(second.banner(for: "alice") == banner)
        #expect(second.banner(for: "bob") == .default)
        var other = banner
        other.backgroundColor = .crimson
        try second.save(other, for: "bob")
        #expect(first.banner(for: "alice") == banner)
        #expect(first.banner(for: "bob") == other)
        #expect(try JSONDecoder().decode(
            BannerConfiguration.self, from: #require(values.data(forKey: "banner-v1:alice"))
        ) == banner)
    }

    @Test func corruptAndUnsupportedRecordsUseDefault() {
        let values = InMemoryKeyValueStore()
        let store = BannerStore(keyValueStore: values)
        for payload in ["not json", "{\"schemaVersion\":99}"] {
            values.set(Data(payload.utf8), forKey: "banner-v1:alice")
            #expect(store.banner(for: "alice") == .default)
        }
    }

    @Test func refusesMissingIdentity() {
        let store = BannerStore(keyValueStore: InMemoryKeyValueStore())
        #expect(throws: BannerStore.SaveError.self) { try store.save(.default, for: " \n") }
    }

    @Test func reportsFailedWrites() {
        let store = BannerStore(keyValueStore: DiscardingBannerKeyValueStore())
        #expect(throws: BannerStore.SaveError.self) { try store.save(.default, for: "alice") }
    }
}

final class DiscardingBannerKeyValueStore: PKeyValueStore {
    func data(forKey: String) -> Data? { nil }
    func string(forKey: String) -> String? { nil }
    func set(_ value: Any?, forKey: String) {}
    func removeObject(forKey: String) {}
    func double(forKey: String) -> Double { 0 }
}
