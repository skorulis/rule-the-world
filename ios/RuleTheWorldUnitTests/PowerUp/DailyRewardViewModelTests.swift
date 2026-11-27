import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct DailyRewardViewModelTests {
    /// 2026-11-23T15:30:00Z
    private let now = Date(timeIntervalSince1970: 1_795_447_800)
    /// 2026-11-24T00:00:00Z
    private let nextMidnight = Date(timeIntervalSince1970: 1_795_478_400)

    private let grantBody = """
        {"powerup":{"id":1,"type":"attack","rarity":"common","bonus":1,"squares":3,"description":"+{bonus} score"},
        "powerups":{"1":2}}
        """

    private func makeModel(
        claimStatus: Int = 200,
        claimBody: String? = nil,
        profileBody: String = "{}",
        profileFails: Bool = false
    ) -> DailyRewardViewModel {
        let tokenStore = AuthTokenStore(keyValueStore: InMemoryKeyValueStore())
        tokenStore.save("session-token")
        let claimBody = claimBody ?? grantBody
        let session = FakeURLSession { request in
            let isClaim = request.url?.path == "/api/powerup/daily"
            if !isClaim && profileFails { throw URLError(.notConnectedToInternet) }
            return (Data((isClaim ? claimBody : profileBody).utf8),
                    HTTPURLResponse(url: request.url!, statusCode: isClaim ? claimStatus : 200,
                                    httpVersion: nil, headerFields: nil)!)
        }
        let fixedNow = now
        let service = AuthenticatedService(tokenStore: tokenStore, urlSession: session)
        return DailyRewardViewModel(
            service: service,
            profileService: ProfileService(
                service: service, store: ProfileSummaryStore(keyValueStore: InMemoryKeyValueStore())),
            now: { fixedNow }
        )
    }

    @Test func nextResetIsTheFollowingUTCMidnight() {
        #expect(DailyRewardViewModel.nextReset(after: now) == nextMidnight)
        let midnight = Date(timeIntervalSince1970: 1_795_392_000) // 2026-11-23T00:00:00Z
        #expect(DailyRewardViewModel.nextReset(after: midnight) == nextMidnight)
        let lastSecond = Date(timeIntervalSince1970: 1_795_478_399) // 2026-11-23T23:59:59Z
        #expect(DailyRewardViewModel.nextReset(after: lastSecond) == nextMidnight)
    }

    @Test func nextResetUsesUTCRegardlessOfLocalDay() {
        // 2026-11-24T09:00:00+10:00 is still 2026-11-23 in UTC.
        let sydneyMorning = Date(timeIntervalSince1970: 1_795_474_800)
        #expect(DailyRewardViewModel.nextReset(after: sydneyMorning) == nextMidnight)
        // 2026-11-23T20:00:00-08:00 is already 2026-11-24 in UTC.
        let losAngelesEvening = Date(timeIntervalSince1970: 1_795_492_800)
        #expect(DailyRewardViewModel.nextReset(after: losAngelesEvening) == nextMidnight.addingTimeInterval(86_400))
    }

    @Test func availabilityFlipsAtAvailableAt() {
        let model = makeModel()
        #expect(!model.isAvailable(at: now))
        #expect(model.remaining(at: now) == nil)
        model.update(availableAt: nextMidnight)
        #expect(!model.isAvailable(at: now))
        #expect(model.remaining(at: now) == .seconds(30_600))
        #expect(model.remaining(at: nextMidnight.addingTimeInterval(-0.2)) == .seconds(1))
        #expect(model.isAvailable(at: nextMidnight))
        #expect(model.remaining(at: nextMidnight) == nil)
    }

    @Test func availabilityToleratesServerNowStampedFractionallyInTheFuture() {
        let model = makeModel()
        // The server returns its own "now" when the reward is claimable, which can land
        // a fraction of a second ahead of the timeline tick rendering the button.
        model.update(availableAt: now.addingTimeInterval(0.4))
        #expect(model.isAvailable(at: now))
        model.update(availableAt: now.addingTimeInterval(2))
        #expect(!model.isAvailable(at: now))
    }

    @Test func successfulClaimRevealsRewardAndStartsCountdown() async {
        let model = makeModel()
        model.update(availableAt: now)
        let response = await model.claim()
        #expect(response?.powerups == ["1": 2])
        #expect(model.reward?.id == 1)
        #expect(model.reward?.displayName == "Common Attack")
        #expect(model.availableAt == nextMidnight)
        #expect(model.errorMessage == nil)
        #expect(!model.isClaiming)
    }

    @Test func alreadyClaimedResyncsCountdownFromProfileWithoutError() async {
        let model = makeModel(
            claimStatus: 409,
            claimBody: #"{"error":"Daily reward already claimed"}"#,
            profileBody: #"{"dailyRewardAvailableAt":"2026-11-24T00:00:00.000Z"}"#
        )
        model.update(availableAt: now)
        #expect(await model.claim() == nil)
        #expect(model.availableAt == nextMidnight)
        #expect(model.reward == nil)
        #expect(model.errorMessage == nil)
    }

    @Test func failureWhileStillAvailableShowsErrorAndKeepsButtonEnabled() async {
        let model = makeModel(
            claimStatus: 500,
            claimBody: "{}",
            profileBody: #"{"dailyRewardAvailableAt":"2026-11-23T15:30:00.000Z"}"#
        )
        model.update(availableAt: now)
        #expect(await model.claim() == nil)
        #expect(model.availableAt == now)
        #expect(model.reward == nil)
        #expect(model.errorMessage != nil)
    }

    @Test func failureWithUnreachableProfileShowsError() async {
        let model = makeModel(claimStatus: 500, claimBody: "{}", profileFails: true)
        model.update(availableAt: now)
        #expect(await model.claim() == nil)
        #expect(model.availableAt == now)
        #expect(model.errorMessage != nil)
    }
}
