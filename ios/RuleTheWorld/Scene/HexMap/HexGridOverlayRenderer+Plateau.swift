import MapKit
import SwiftUI
import os

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
    var topPaths: [PlateauColor: CGMutablePath] = [:]
    var flipping: [FlippingCell] = []
}

extension HexGridOverlayRenderer {
    /// Maps a cell's ownership state and today's visit to its display tint:
    /// green when owned and visited today, yellow when visited but not owned.
    func plateauTint(for cellState: HexState, visited: Bool) -> PlateauColor {
        guard visited else { return .normal(cellState) }
        return cellState.isOwned ? .ownedToday : .visitedUnowned
    }

    /// Vertical lift for a plateau level, in drawing units, proportional to
    /// the hexagon edge length so extrusions scale with the hexes on screen.
    func lift(_ level: Int, hexEdge: CGFloat) -> CGFloat {
        CGFloat(level) * HexElevationPolicy.stepFraction * hexEdge
    }

    func drawPlateau(
        cell: PlateauCell,
        geometry: CollectedGeometry,
        hexEdge: CGFloat,
        zoomScale: MKZoomScale,
        in context: CGContext
    ) {
        let ownLift = lift(cell.key.level, hexEdge: hexEdge)
        for edge in cell.edges {
            guard isPlateauBoundary(edge: edge, in: geometry.edgePlateaus) else { continue }
            // Only south-facing edges show a wall; upper-side walls are
            // occluded by the top face and would show through as a dark rim.
            guard (edge.start.y + edge.end.y) / 2 > cell.sortY else { continue }
            let neighbour = maxNeighbourLevel(edge: edge, excluding: cell.key, in: geometry.edgePlateaus)
            let otherLift = lift(neighbour, hexEdge: hexEdge)
            if ownLift > otherLift {
                drawWall(
                    edge: edge, topLift: ownLift, bottomLift: otherLift,
                    color: wallColor(for: cell.key.tint), in: context
                )
            }
        }
        var topPath = CGMutablePath()
        appendPath(to: &topPath, boundary: cell.boundary, lift: ownLift)
        context.addPath(topPath)
        context.setFillColor(
            UIColor(cell.key.tint.color ?? .gray).withAlphaComponent(0.45).cgColor
        )
        context.fillPath()
    }

    func strokeOverlays(
        geometry: CollectedGeometry,
        hexEdge: CGFloat,
        zoomScale: MKZoomScale,
        in context: CGContext
    ) {
        context.setLineJoin(.round)
        context.setLineCap(.round)
        let paths = boundaryPaths(geometry: geometry, hexEdge: hexEdge)
        for (strokeTint, path) in paths {
            guard let color = strokeTint.color else { continue }
            if let interior = geometry.topPaths[strokeTint] {
                context.saveGState()
                context.addPath(interior)
                context.clip()
                context.addPath(path)
                context.setStrokeColor(glowColor(for: color).cgColor)
                context.setLineWidth(10 / zoomScale)
                context.setShadow(
                    offset: .zero, blur: 8 / zoomScale,
                    color: glowColor(for: color).cgColor
                )
                context.strokePath()
                context.restoreGState()
            }
            context.addPath(path)
            context.setStrokeColor(UIColor(color).cgColor)
            context.setLineWidth(2 / zoomScale)
            context.strokePath()
        }
    }

    func collect(input: CollectInput, hexEdge: CGFloat) -> CollectedGeometry {
        var geometry = CollectedGeometry()
        for cell in input.cells {
            let boundary = grid.boundary(of: cell)
            guard !boundary.isEmpty else { continue }
            let level = input.aggregation.levels[cell] ?? 0
            let cellState = input.aggregation.states[cell] ?? .unclaimed
            let visited = input.aggregation.visits.contains(cell)
            if let animation = input.changed[cell], input.progress < 1 {
                geometry.flipping.append(
                    FlippingCell(
                        boundary: boundary,
                        lift: lift(level, hexEdge: hexEdge),
                        animation: animation,
                    )
                )
            } else if input.exploring {
                guard cellState != .unclaimed else { continue }
                let fillState = cellState == .contested ? .owned : cellState
                let tint = plateauTint(for: fillState, visited: visited)
                appendCell(
                    to: &geometry, key: PlateauKey(tint: tint, level: level),
                    boundary: boundary, hexEdge: hexEdge
                )
            } else if cellState != .unclaimed {
                let tint = plateauTint(for: cellState, visited: visited)
                appendCell(
                    to: &geometry, key: PlateauKey(tint: tint, level: level),
                    boundary: boundary, hexEdge: hexEdge
                )
            }
        }
        geometry.cells.sort { $0.sortY < $1.sortY }
        return geometry
    }

    func appendCell(
        to geometry: inout CollectedGeometry,
        key: PlateauKey,
        boundary: [CLLocationCoordinate2D],
        hexEdge: CGFloat
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
        var topPath = CGMutablePath()
        appendPath(to: &topPath, boundary: boundary, lift: lift(key.level, hexEdge: hexEdge))
        let union = geometry.topPaths[key.tint] ?? CGMutablePath()
        union.addPath(topPath)
        geometry.topPaths[key.tint] = union
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
        hexEdge: CGFloat
    ) -> [PlateauColor: CGMutablePath] {
        var paths: [PlateauColor: CGMutablePath] = [:]
        for cell in geometry.cells {
            for edge in cell.edges where isPlateauBoundary(edge: edge, in: geometry.edgePlateaus) {
                let strokeKey = geometry.edgePlateaus[edge.key]?.keys.max() ?? cell.key
                let edgeLift = lift(strokeKey.level, hexEdge: hexEdge)
                let path = paths[strokeKey.tint] ?? CGMutablePath()
                path.move(to: CGPoint(x: edge.start.x, y: edge.start.y - edgeLift))
                path.addLine(to: CGPoint(x: edge.end.x, y: edge.end.y - edgeLift))
                paths[strokeKey.tint] = path
            }
        }
        return paths
    }

    /// A bright, washed-out version of the plateau color used for the
    /// inner glow bleeding inward from territory borders.
    func glowColor(for color: Color) -> UIColor {
        let base = UIColor(color)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        base.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return UIColor(
            red: red + (1 - red) * 0.65,
            green: green + (1 - green) * 0.65,
            blue: blue + (1 - blue) * 0.65,
            alpha: 0.85
        )
    }

    func wallColor(for tint: PlateauColor) -> UIColor {
        let base = UIColor(tint.color ?? .gray)
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
        context.addPath(path)
        let uiColor = shown.color.map(UIColor.init) ?? .gray
        context.setFillColor(uiColor.withAlphaComponent(shown == .unclaimed ? 0 : 0.45).cgColor)
        context.setStrokeColor(uiColor.cgColor)
        context.setLineWidth(1 / zoomScale)
        context.drawPath(using: .fillStroke)
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
