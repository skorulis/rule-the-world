import Foundation
import Testing
@testable import RuleTheWorld

struct DebugSettingsTests {
    private let defaults: UserDefaults
    private let settings: DebugSettings

    init() {
        defaults = UserDefaults(suiteName: "DebugSettingsTests")!
        defaults.removePersistentDomain(forName: "DebugSettingsTests")
        settings = DebugSettings(defaults: defaults)
    }

    @Test func defaultsToLocal() {
        #expect(settings.endpoint == .local)
    }

    @Test func persistsEndpoint() {
        settings.endpoint = .mock
        #expect(DebugSettings(defaults: defaults).endpoint == .mock)
    }

    @Test func fallsBackToLocalForInvalidValue() {
        defaults.set("bogus", forKey: DebugSettings.endpointKey)
        #expect(settings.endpoint == .local)
    }
}
