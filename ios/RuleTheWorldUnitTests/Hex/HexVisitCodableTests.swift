import Foundation
import Testing
@testable import RuleTheWorld

struct HexVisitCodableTests {
    private func payload(
        cell: String = "8a283082876ffff", date: String = "2026-11-20T10:00:00Z",
        score: Double = 12.5, lastScore: Double = 0.5, total: Int = 42
    ) -> Data {
        Data("""
            {"cell":"\(cell)","lastVisit":"\(date)","score":\(score),"lastScore":\(lastScore),"total":\(total)}
            """.utf8)
    }

    @Test func decodesISO8601DatesWithAndWithoutFractionalSeconds() throws {
        for (date, fraction) in [
            ("2026-11-20T10:00:00Z", 0.0),
            ("2026-11-20T10:00:00.125Z", 0.125),
            ("2026-11-20T12:00:00.125+02:00", 0.125)
        ] {
            let visit = try JSONDecoder().decode(HexVisit.self, from: payload(date: date))
            let expected = try #require(ISO8601DateFormatter().date(from: "2026-11-20T10:00:00Z"))
            #expect(abs(visit.lastVisit.timeIntervalSince(expected) - fraction) < 0.000_001)
            #expect(visit.cell == HexCell(rawValue: 0x8A283082876FFFF))
            #expect(visit.score == 12.5)
            #expect(visit.lastScore == 0.5)
            #expect(visit.total == 42)
        }
    }

    @Test func encodesWireFormatAndRoundTrips() throws {
        let original = try JSONDecoder().decode(
            HexVisit.self, from: payload(date: "2026-11-20T10:00:00.125Z")
        )
        let data = try JSONEncoder().encode(original)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["cell"] as? String == "8a283082876ffff")
        #expect(json["lastVisit"] as? String == "2026-11-20T10:00:00.125Z")
        #expect(try JSONDecoder().decode(HexVisit.self, from: data) == original)
    }

    @Test func rejectsInvalidWireValues() {
        for data in [
            payload(cell: "invalid"), payload(date: "invalid"),
            payload(score: -1), payload(lastScore: -0.1), payload(lastScore: 1.1), payload(total: -1)
        ] {
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(HexVisit.self, from: data)
            }
        }
    }
}
