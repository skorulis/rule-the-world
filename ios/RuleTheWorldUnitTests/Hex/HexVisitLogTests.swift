import Foundation
import Testing
@testable import RuleTheWorld

struct HexVisitLogTests {
    private let cell = HexCell(rawValue: 0x8A283082876FFFF)

    private func entry(
        score: Double,
        speed: Double? = nil,
        timestamp: Date = Date(timeIntervalSince1970: 1_700_000_000),
        latitude: Double = -33.89,
        longitude: Double = 151.19,
        id: Int64? = nil,
        locationType: LocationType = .foreground,
        count: Int = 1
    ) -> HexVisitLog {
        HexVisitLog(
            id: id,
            timestamp: timestamp,
            cell: cell,
            latitude: latitude,
            longitude: longitude,
            speed: speed,
            score: score,
            locationType: locationType,
            count: count
        )
    }

    @Test func mergeTakesMaxScoreAndMinSpeed() {
        let a = entry(score: 0.5, speed: 8)
        let b = entry(score: 1, speed: 4)
        let merged = a.merging(b)
        #expect(merged.score == 1)
        #expect(merged.speed == 4)
    }

    @Test func mergeIgnoresNilSpeedForMin() {
        #expect(entry(score: 1, speed: nil).merging(entry(score: 1, speed: 5)).speed == 5)
        #expect(entry(score: 1, speed: 5).merging(entry(score: 1, speed: nil)).speed == 5)
        #expect(entry(score: 1, speed: nil).merging(entry(score: 1, speed: nil)).speed == nil)
    }

    @Test func mergeTakesTimeAndPositionFromHigherScoreEntry() {
        let slow = entry(
            score: 1, speed: 1,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            latitude: -33.89, longitude: 151.19
        )
        let fast = entry(
            score: 0.5, speed: 8,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            latitude: -33.90, longitude: 151.20
        )
        let merged = slow.merging(fast)
        #expect(merged.timestamp == slow.timestamp)
        #expect(merged.latitude == slow.latitude)
        #expect(merged.longitude == slow.longitude)
        let reversed = fast.merging(slow)
        #expect(reversed.timestamp == slow.timestamp)
        #expect(reversed.latitude == slow.latitude)
        #expect(reversed.longitude == slow.longitude)
    }

    @Test func mergeEqualScoreTakesLowerSpeedPosition() {
        let slow = entry(
            score: 1, speed: 1,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            latitude: -33.89, longitude: 151.19
        )
        let fast = entry(
            score: 1, speed: 8,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            latitude: -33.90, longitude: 151.20
        )
        let merged = slow.merging(fast)
        #expect(merged.timestamp == slow.timestamp)
        #expect(merged.latitude == slow.latitude)
        let reversed = fast.merging(slow)
        #expect(reversed.timestamp == slow.timestamp)
        #expect(reversed.latitude == slow.latitude)
    }

    @Test func mergeTakesLocationTypeFromHigherScoreEntry() {
        let foreground = entry(score: 1, locationType: .foreground)
        let background = entry(score: 0.5, locationType: .background)
        #expect(foreground.merging(background).locationType == .foreground)
        #expect(background.merging(foreground).locationType == .foreground)
    }

    @Test func mergeEqualScoreTakesLocationTypeFromLowerSpeedEntry() {
        let slow = entry(score: 1, speed: 1, locationType: .background)
        let fast = entry(score: 1, speed: 8, locationType: .foreground)
        #expect(slow.merging(fast).locationType == .background)
        #expect(fast.merging(slow).locationType == .background)
    }

    @Test func mergeIncrementsCount() {
        #expect(entry(score: 0.5, count: 3).merging(entry(score: 1)).count == 4)
        #expect(entry(score: 1).merging(entry(score: 0.5)).count == 2)
    }

    @Test func mergePreservesReceiverId() {
        let merged = entry(score: 0.5, id: 42).merging(entry(score: 1))
        #expect(merged.id == 42)
        #expect(entry(score: 0.5).merging(entry(score: 1, id: 7)).id == nil)
    }
}
