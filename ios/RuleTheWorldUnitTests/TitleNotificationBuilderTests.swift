import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct TitleNotificationBuilderTests {
    private var builder: TitleNotificationBuilder {
        TitleNotificationBuilder(
            catalog: RankCatalog(data: Data(#"""
                {"country":[
                {"number":1,"name":"King","rarity":"mythic","description":"Ruler","icon":"RankKing"},
                {"number":15,"name":"Wanderer","rarity":"common","description":"Traveler"}],
                "global":[{"number":1,"name":"Emperor","rarity":"mythic","description":"World ruler"}]}
                """#.utf8)),
            regionNames: RegionNameCatalog(data: Data(#"{"7":"Australia"}"#.utf8))
        )
    }

    private func ranking(_ number: Int, id: Int64 = 7, type: String = "country") -> ProfileSummary.Ranking {
        ProfileSummary.Ranking(id: id, type: type, number: number, visited: 5, owned: 3)
    }

    @Test func newTitleIncludesCatalogStyleAndRegion() throws {
        let notifications = builder.notifications(from: [], to: [ranking(1)])
        let notification = try #require(notifications.first)
        #expect(notifications.count == 1)
        #expect(notification.title == "New title!")
        #expect(notification.message == "You have gained the King title in Australia")
        #expect(notification.icon == "RankKing")
        #expect(notification.rarity == .mythic)
    }

    @Test func notifiesForPromotionsButNotUnchangedDemotedOrLostTitles() {
        #expect(builder.notifications(from: [ranking(15)], to: [ranking(1)]).count == 1)
        #expect(builder.notifications(from: [ranking(1)], to: [ranking(1)]).isEmpty)
        #expect(builder.notifications(from: [ranking(1)], to: [ranking(15)]).isEmpty)
        #expect(builder.notifications(from: [ranking(1)], to: []).isEmpty)
    }

    @Test func identifiesTitlesByBothRegionAndTypeAndDeduplicatesResponse() {
        let notifications = builder.notifications(
            from: [ranking(1)],
            to: [ranking(1), ranking(1, id: 8), ranking(1, type: "global"), ranking(1, type: "global")]
        )
        #expect(notifications.count == 2)
        #expect(notifications[0].message == "You have gained the King title in Region #8")
        #expect(notifications[1].message == "You have gained the Emperor title in World")
    }

    @Test func unknownCatalogEntriesHaveFallbackAndInvalidRankingsAreIgnored() {
        let notifications = builder.notifications(from: [], to: [
            ranking(99), ranking(0), ranking(1, id: 0), ranking(1, type: "unknown"),
        ])
        #expect(notifications.count == 1)
        #expect(notifications.first?.message == "You have gained the Title #99 title in Australia")
        #expect(notifications.first?.icon == nil)
        #expect(notifications.first?.rarity == nil)
    }
}
