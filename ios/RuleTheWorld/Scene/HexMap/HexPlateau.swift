import CoreLocation
import MapKit

struct QuantizedMapPoint: Hashable, Comparable {
    let xCoord: Int64
    let yCoord: Int64

    init(_ point: MKMapPoint) {
        xCoord = Int64((point.x * 4).rounded())
        yCoord = Int64((point.y * 4).rounded())
    }

    static func < (lhs: QuantizedMapPoint, rhs: QuantizedMapPoint) -> Bool {
        lhs.xCoord != rhs.xCoord ? lhs.xCoord < rhs.xCoord : lhs.yCoord < rhs.yCoord
    }
}

struct HexEdgeKey: Hashable {
    let start: QuantizedMapPoint
    let end: QuantizedMapPoint

    init(_ pointA: MKMapPoint, _ pointB: MKMapPoint) {
        let first = QuantizedMapPoint(pointA)
        let second = QuantizedMapPoint(pointB)
        (start, end) = first < second ? (first, second) : (second, first)
    }
}

struct HexCellEdge {
    let key: HexEdgeKey
    let start: CGPoint
    let end: CGPoint
}

/// A plateau groups cells that share the same state and elevation level.
/// Edges between equal plateaus get no border or wall, keeping joined
/// regions as a single merged outline.
struct PlateauKey: Hashable, Comparable {
    let state: HexState
    let level: Int

    static func < (lhs: PlateauKey, rhs: PlateauKey) -> Bool {
        lhs.state != rhs.state ? lhs.state < rhs.state : lhs.level < rhs.level
    }
}

struct AggregatedResult {
    var states: [HexCell: HexState]
    var levels: [HexCell: Int]
    var visits: Set<HexCell>
}

struct CollectInput {
    var cells: [HexCell]
    var aggregation: AggregatedResult
    var changed: [HexCell: (from: HexState, to: HexState)]
    var progress: Double
    var exploring: Bool
}
