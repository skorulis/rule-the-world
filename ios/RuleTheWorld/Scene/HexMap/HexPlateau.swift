import CoreLocation
import MapKit
import SwiftUI

/// Display color of a plateau: the state color normally, or the
/// visit-today overrides (green when owned, yellow when not).
enum PlateauColor: Hashable, Comparable {
    case normal(HexState)
    case ownedToday
    case visitedUnowned

    private var rank: Int {
        switch self {
        case .normal(let state):
            return HexState.allCases.firstIndex(of: state) ?? 0
        case .visitedUnowned:
            return HexState.allCases.count
        case .ownedToday:
            return HexState.allCases.count + 1
        }
    }

    static func < (lhs: PlateauColor, rhs: PlateauColor) -> Bool {
        lhs.rank < rhs.rank
    }

    var color: Color? {
        switch self {
        case .normal(let state):
            return state.color
        case .ownedToday:
            return .green
        case .visitedUnowned:
            return .yellow
        }
    }
}

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
    let tint: PlateauColor
    let level: Int

    static func < (lhs: PlateauKey, rhs: PlateauKey) -> Bool {
        lhs.tint != rhs.tint ? lhs.tint < rhs.tint : lhs.level < rhs.level
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
