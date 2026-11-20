import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct ProfileViewModelTests {
    private func makeModel(
        handler: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)
    ) throws -> (ProfileViewModel, AuthManager) {
        let database = try AppDatabase.inMemory()
        let store = HexInfoStore(database: database)
        let tokenStore = AuthTokenStore(keyValueStore: InMemoryKeyValueStore())
        tokenStore.save("session-token")
        let session = FakeURLSession(handler: handler)
        let service = AuthenticatedService(tokenStore: tokenStore, urlSession: session)
        let manager = AuthManager(
            service: AuthService(urlSession: session),
            authenticatedService: service,
            tokenStore: tokenStore,
            database: database,
            visitStore: store
        )
        let names = RegionNameCatalog(data: Data(#"{"1":"Zambia","2":"Australia","3":"Australia","4":" "}"#.utf8))
        return (ProfileViewModel(authManager: manager, service: service, regionNames: names), manager)
    }

    @Test func startsWithoutInventedCounts() throws {
        let (model, _) = try makeModel { _ in throw URLError(.notConnectedToInternet) }
        #expect(model.visitedHexCount == nil)
        #expect(model.ownedHexCount == nil)
        #expect(model.regions.isEmpty)
    }

    @Test func loadsServerTotalsAndSortsNamedRegionsDroppingIncompleteRows() async throws {
        let (model, _) = try makeModel { request in
            #expect(request.url?.path == "/api/me")
            return (Data("""
                {"visited":25,"owned":8,"regions":[
                {"id":1,"visited":10,"owned":5},
                {"id":3,"visited":2,"owned":0},
                {"id":2,"visited":6,"owned":3},
                {"id":99,"visited":1,"owned":0},
                {"id":4,"visited":1,"owned":0},
                {"id":0,"visited":1,"owned":0},
                {"id":1,"visited":10,"owned":5},
                {"id":5,"visited":1}]}
                """.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        await model.load()
        #expect(model.visitedHexCount == 25)
        #expect(model.ownedHexCount == 8)
        #expect(model.regions.map(\.id) == [2, 3, 1])
        #expect(model.regions.map(\.name) == ["Australia", "Australia", "Zambia"])
        #expect(model.regions.map(\.visited) == [6, 2, 10])
        #expect(model.regions.map(\.owned) == [3, 0, 5])
    }

    @Test func refreshesAndRetainsLastSuccessOnFailure() async throws {
        let replies = Replies()
        let (model, _) = try makeModel { request in
            let body = try await replies.next()
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(body.utf8), response)
        }
        await model.load()
        #expect(model.visitedHexCount == 10)
        await model.load()
        #expect(model.visitedHexCount == 20)
        #expect(model.ownedHexCount == 7)
        await model.load()
        #expect(model.visitedHexCount == 20)
        #expect(model.ownedHexCount == 7)
    }

    @Test func cancelledLoadDoesNotPublishData() async throws {
        let (model, _) = try makeModel { request in
            withUnsafeCurrentTask { $0?.cancel() }
            return (Data(#"{"visited":10,"owned":5}"#.utf8),
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let task = Task { await model.load() }
        await task.value
        #expect(model.visitedHexCount == nil)
        #expect(model.ownedHexCount == nil)
        #expect(model.regions.isEmpty)
    }

    @Test func signOutStillClearsAuthentication() throws {
        let (model, manager) = try makeModel { _ in throw URLError(.unsupportedURL) }
        #expect(manager.isSignedIn)
        model.signOut()
        #expect(!manager.isSignedIn)
    }

    private actor Replies {
        private var count = 0

        func next() throws -> String {
            count += 1
            switch count {
            case 1: return #"{"visited":10,"owned":5,"regions":[]}"#
            case 2: return #"{"visited":20,"owned":7,"regions":[]}"#
            default: throw URLError(.notConnectedToInternet)
            }
        }
    }
}
