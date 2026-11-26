import MapKit
import SwiftUI
import os

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

struct PlateauCell {
    let key: PlateauKey
    let sortY: CGFloat
    let boundary: [CLLocationCoordinate2D]
    let edges: [HexCellEdge]
}

struct FlippingCell {
    let boundary: [CLLocationCoordinate2D]
    let lift: CGFloat
    let animation: (from: HexState, to: HexState)
}

struct CollectedGeometry {
    var cells: [PlateauCell] = []
    var edgePlateaus: [HexEdgeKey: [PlateauKey: Int]] = [:]
    var todayCells: [(boundary: [CLLocationCoordinate2D], lift: CGFloat)] = []
    var flipping: [FlippingCell] = []
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

extension HexGridOverlayRenderer {
    func liftPoints(_ level: Int, zoomScale: MKZoomScale) -> CGFloat {
        CGFloat(level) * HexElevationPolicy.stepPoints / zoomScale
    }

    func drawPlateau(
        cell: PlateauCell,
        geometry: CollectedGeometry,
        ownLift: CGFloat,
        zoomScale: MKZoomScale,
        in context: CGContext
    ) {
        for edge in cell.edges {
            guard isPlateauBoundary(edge: edge, in: geometry.edgePlateaus) else { continue }
            // Only south-facing edges show a wall; upper-side walls are
            // occluded by the top face and would show through as a dark rim.
            guard (edge.start.y + edge.end.y) / 2 > cell.sortY else { continue }
            let neighbour = maxNeighbourLevel(edge: edge, excluding: cell.key, in: geometry.edgePlateaus)
            let otherLift = liftPoints(neighbour, zoomScale: zoomScale)
            if ownLift > otherLift {
                drawWall(
                    edge: edge, topLift: ownLift, bottomLift: otherLift,
                    color: wallColor(for: cell.key.state), in: context
                )
            }
        }
        var topPath = CGMutablePath()
        appendPath(to: &topPath, boundary: cell.boundary, lift: ownLift)
        if cell.key.state == .contested {
            var outline = CGMutablePath()
            for edge in cell.edges where isPlateauBoundary(edge: edge, in: geometry.edgePlateaus) {
                outline.move(to: CGPoint(x: edge.start.x, y: edge.start.y - ownLift))
                outline.addLine(to: CGPoint(x: edge.end.x, y: edge.end.y - ownLift))
            }
            drawContested(path: topPath, outline: outline, zoomScale: zoomScale, in: context)
        } else {
            context.addPath(topPath)
            context.setFillColor(
                UIColor(cell.key.state.color ?? .gray).withAlphaComponent(0.45).cgColor
            )
            context.fillPath()
        }
    }

    func strokeOverlays(geometry: CollectedGeometry, zoomScale: MKZoomScale, in context: CGContext) {
        context.setLineWidth(2 / zoomScale)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        for (strokeState, path) in boundaryPaths(geometry: geometry, zoomScale: zoomScale) {
            guard strokeState != .contested, let color = strokeState.color else { continue }
            context.addPath(path)
            context.setStrokeColor(UIColor(color).cgColor)
            context.strokePath()
        }
        context.setStrokeColor(UIColor.systemGreen.cgColor)
        context.setLineWidth(3 / zoomScale)
        for today in geometry.todayCells {
            var path = CGMutablePath()
            appendPath(to: &path, boundary: today.boundary, lift: today.lift)
            context.addPath(path)
        }
        context.strokePath()
    }

    func collect(input: CollectInput, zoomScale: MKZoomScale) -> CollectedGeometry {
        var geometry = CollectedGeometry()
        for cell in input.cells {
            let boundary = grid.boundary(of: cell)
            guard !boundary.isEmpty else { continue }
            let level = input.aggregation.levels[cell] ?? 0
            if input.aggregation.visits.contains(cell) {
                geometry.todayCells.append((boundary, liftPoints(level, zoomScale: zoomScale)))
            }
            let cellState = input.aggregation.states[cell] ?? .unclaimed
            if let animation = input.changed[cell], input.progress < 1 {
                geometry.flipping.append(
                    FlippingCell(
                        boundary: boundary,
                        lift: liftPoints(level, zoomScale: zoomScale),
                        animation: animation,
                    )
                )
            } else if input.exploring {
                guard cellState != .unclaimed else { continue }
                let fillState = cellState == .contested ? .owned : cellState
                appendCell(
                    to: &geometry, key: PlateauKey(state: fillState, level: level), boundary: boundary
                )
            } else if cellState != .unclaimed {
                appendCell(to: &geometry, key: PlateauKey(state: cellState, level: level), boundary: boundary)
            }
        }
        geometry.cells.sort { $0.sortY < $1.sortY }
        return geometry
    }

    func appendCell(
        to geometry: inout CollectedGeometry,
        key: PlateauKey,
        boundary: [CLLocationCoordinate2D]
    ) {
        var sortY: CGFloat = 0
        var edges: [HexCellEdge] = []
        for index in boundary.indices {
            let next = index == boundary.index(before: boundary.endIndex)
                ? boundary.startIndex
                : boundary.index(after: index)
            let pointA = MKMapPoint(boundary[index])
            let pointB = MKMapPoint(boundary[next])
            let edgeKey = HexEdgeKey(pointA, pointB)
            sortY += point(for: pointA).y
            geometry.edgePlateaus[edgeKey, default: [:]][key, default: 0] += 1
            edges.append(HexCellEdge(key: edgeKey, start: point(for: pointA), end: point(for: pointB)))
        }
        geometry.cells.append(
            PlateauCell(key: key, sortY: sortY / CGFloat(boundary.count), boundary: boundary, edges: edges)
        )
    }

    func isPlateauBoundary(edge: HexCellEdge, in edgePlateaus: [HexEdgeKey: [PlateauKey: Int]]) -> Bool {
        guard let neighbours = edgePlateaus[edge.key] else { return false }
        return neighbours.count > 1 || neighbours.values.reduce(0, +) == 1
    }

    func maxNeighbourLevel(
        edge: HexCellEdge,
        excluding own: PlateauKey,
        in edgePlateaus: [HexEdgeKey: [PlateauKey: Int]]
    ) -> Int {
        edgePlateaus[edge.key]?.keys.filter { $0 != own }.map(\.level).max() ?? 0
    }

    func boundaryPaths(
        geometry: CollectedGeometry,
        zoomScale: MKZoomScale
    ) -> [HexState: CGMutablePath] {
        var paths: [HexState: CGMutablePath] = [:]
        for cell in geometry.cells {
            for edge in cell.edges where isPlateauBoundary(edge: edge, in: geometry.edgePlateaus) {
                let strokeKey = geometry.edgePlateaus[edge.key]?.keys.max() ?? cell.key
                let lift = liftPoints(strokeKey.level, zoomScale: zoomScale)
                let path = paths[strokeKey.state] ?? CGMutablePath()
                path.move(to: CGPoint(x: edge.start.x, y: edge.start.y - lift))
                path.addLine(to: CGPoint(x: edge.end.x, y: edge.end.y - lift))
                paths[strokeKey.state] = path
            }
        }
        return paths
    }

    func wallColor(for cellState: HexState) -> UIColor {
        if cellState == .contested {
            return UIColor(red: 0.33, green: 0.12, blue: 0.42, alpha: 0.95)
        }
        let base = UIColor(cellState.color ?? .gray)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        base.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return UIColor(red: red * 0.55, green: green * 0.55, blue: blue * 0.55, alpha: 0.95)
    }

    func drawWall(
        edge: HexCellEdge,
        topLift: CGFloat,
        bottomLift: CGFloat,
        color: UIColor,
        in context: CGContext
    ) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: edge.start.x, y: edge.start.y - topLift))
        path.addLine(to: CGPoint(x: edge.end.x, y: edge.end.y - topLift))
        path.addLine(to: CGPoint(x: edge.end.x, y: edge.end.y - bottomLift))
        path.addLine(to: CGPoint(x: edge.start.x, y: edge.start.y - bottomLift))
        path.closeSubpath()
        context.addPath(path)
        context.setFillColor(color.cgColor)
        context.fillPath()
    }

    func changedCells(at resolution: Int) -> [HexCell: (from: HexState, to: HexState)] {
        state.withLock { state in
            if let cached = state.changedCellsCache[resolution] {
                return cached
            }
            let oldStates = state.previousSnapshot.aggregated(at: resolution, grid: grid)
            let newStates = state.snapshot.aggregated(at: resolution, grid: grid)
            var changed: [HexCell: (from: HexState, to: HexState)] = [:]
            for cell in Set(oldStates.keys).union(newStates.keys) {
                let from = oldStates[cell] ?? .unclaimed
                let to = newStates[cell] ?? .unclaimed
                if from != to {
                    changed[cell] = (from, to)
                }
            }
            state.changedCellsCache[resolution] = changed
            return changed
        }
    }

    func drawFlip(
        cell: FlippingCell,
        progress: Double,
        zoomScale: MKZoomScale,
        in context: CGContext
    ) {
        let lift = cell.lift
        let animation = cell.animation
        let points = cell.boundary.map { point(for: MKMapPoint($0)) }
        guard !points.isEmpty else { return }
        let center = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y - lift) }
            .applying(CGAffineTransform(scaleX: 1 / CGFloat(points.count), y: 1 / CGFloat(points.count)))
        let shown: HexState
        let scaleX: CGFloat
        if progress < 0.5 {
            shown = animation.from
            scaleX = CGFloat(1 - 2 * progress)
        } else {
            shown = animation.to
            scaleX = CGFloat(2 * progress - 1)
        }
        if animation.to.isOwned {
            drawCaptureRing(cell: cell, center: center, progress: progress, zoomScale: zoomScale, in: context)
        }
        let pop = 1 + 0.15 * CGFloat(sin(progress * .pi))
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.scaleBy(x: max(scaleX, 0.01) * pop, y: pop)
        context.translateBy(x: -center.x, y: -center.y)
        var path = CGMutablePath()
        appendPath(to: &path, boundary: cell.boundary, lift: lift)
        if shown == .contested {
            drawContested(path: path, outline: path, zoomScale: zoomScale, in: context)
        } else {
            context.addPath(path)
            let uiColor = shown.color.map(UIColor.init) ?? .gray
            context.setFillColor(uiColor.withAlphaComponent(shown == .unclaimed ? 0 : 0.45).cgColor)
            context.setStrokeColor(uiColor.cgColor)
            context.setLineWidth(1 / zoomScale)
            context.drawPath(using: .fillStroke)
        }
        context.restoreGState()
    }

    /// An expanding hex outline radiating from a captured cell, starting as
    /// the new (owned) face of the flip appears and fading as it grows.
    func drawCaptureRing(
        cell: FlippingCell,
        center: CGPoint,
        progress: Double,
        zoomScale: MKZoomScale,
        in context: CGContext
    ) {
        let ringProgress = CGFloat(max(progress - 0.35, 0) / 0.65)
        guard ringProgress > 0 else { return }
        var transform = CGAffineTransform(translationX: center.x, y: center.y)
            .scaledBy(x: 1 + 0.6 * ringProgress, y: 1 + 0.6 * ringProgress)
            .translatedBy(x: -center.x, y: -center.y)
        var hexPath = CGMutablePath()
        appendPath(to: &hexPath, boundary: cell.boundary, lift: cell.lift)
        guard let ringPath = hexPath.copy(using: &transform) else { return }
        context.addPath(ringPath)
        context.setStrokeColor(UIColor.white.withAlphaComponent((1 - ringProgress) * 0.9).cgColor)
        context.setLineWidth((3 - ringProgress) / zoomScale)
        context.strokePath()
    }

    func drawContested(path: CGPath, outline: CGPath, zoomScale: MKZoomScale, in context: CGContext) {
        let bounds = path.boundingBoxOfPath
        let padded = bounds.insetBy(dx: -2 / zoomScale, dy: -2 / zoomScale)
        let halves: [(UIColor, CGRect)] = [
            (UIColor(Color.red), CGRect(x: padded.minX, y: padded.minY,
                                       width: bounds.midX - padded.minX, height: padded.height)),
            (UIColor(Color.blue), CGRect(x: bounds.midX, y: padded.minY,
                                        width: padded.maxX - bounds.midX, height: padded.height)),
        ]
        for (color, clip) in halves {
            context.saveGState()
            context.clip(to: clip)
            context.addPath(path)
            context.setFillColor(color.withAlphaComponent(0.45).cgColor)
            context.fillPath()
            context.addPath(outline)
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(2 / zoomScale)
            context.strokePath()
            context.restoreGState()
        }
    }

    func aggregated(
        at resolution: Int, exploring: Bool
    ) -> AggregatedResult {
        state.withLock { state in
            if let cached = state.aggregateCache[resolution], let visits = state.visitCache[resolution] {
                return AggregatedResult(states: cached.states, levels: cached.levels, visits: visits)
            }
            let result = exploring
                ? state.snapshot.aggregatedPersonalWithLevels(at: resolution, grid: grid)
                : state.snapshot.aggregatedWithLevels(at: resolution, grid: grid)
            let visits = state.snapshot.aggregatedVisits(at: resolution, grid: grid)
            state.aggregateCache[resolution] = result
            state.visitCache[resolution] = visits
            return AggregatedResult(states: result.states, levels: result.levels, visits: visits)
        }
    }

    func appendPath(to path: inout CGMutablePath, boundary: [CLLocationCoordinate2D], lift: CGFloat = 0) {
        for (index, coordinate) in boundary.enumerated() {
            let point = point(for: MKMapPoint(coordinate))
            let lifted = CGPoint(x: point.x, y: point.y - lift)
            if index == 0 {
                path.move(to: lifted)
            } else {
                path.addLine(to: lifted)
            }
        }
        path.closeSubpath()
    }
}
