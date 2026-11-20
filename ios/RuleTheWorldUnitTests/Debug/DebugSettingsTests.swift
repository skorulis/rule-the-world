import Foundation
import Testing
@testable import RuleTheWorld

struct DebugSettingsTests {
    private let defaults: UserDefaults
    private let settings: DebugSettings

    init() {
        defaults = UserDefaults(suiteName: "DebugSettingsTests.\(UUID().uuidString)")!
        settings = DebugSettings(defaults: defaults)
    }

    @Test func defaultsToLocal() {
        #expect(settings.endpoint == .local)
    }

    @Test func persistsEndpoint() {
        settings.endpoint = .mock
        #expect(DebugSettings(defaults: defaults).endpoint == .mock)
    }

    @Test func persistsProductionEndpoint() {
        settings.endpoint = .production
        #expect(DebugSettings(defaults: defaults).endpoint == .production)
    }

    @Test func productionIsAvailableInPicker() {
        #expect(NetworkEndpoint.allCases.contains(.production))
        #expect(NetworkEndpoint.production.title == "Production (rule-the-world.vercel.app)")
    }

    @Test func endpointBaseURLs() {
        #expect(NetworkEndpoint.local.baseURL == "http://localhost:3001")
        #expect(NetworkEndpoint.mock.baseURL == "http://localhost:3001")
        #expect(NetworkEndpoint.production.baseURL == "https://rule-the-world.vercel.app")
    }

    @Test func productionUsesRealSession() {
        #expect(NetworkEndpoint.production.makeSession() is URLSession)
    }

    @Test func fallsBackToLocalForInvalidValue() {
        defaults.set("bogus", forKey: DebugSettings.endpointKey)
        #expect(settings.endpoint == .local)
    }
}
