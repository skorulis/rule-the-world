import MapKit
import SwiftUI
import os

private struct QuantizedMapPoint: Hashable, Comparable {
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

private struct HexEdgeKey: Hashable {
    let start: QuantizedMapPoint
    let end: QuantizedMapPoint

    init(_ pointA: MKMapPoint, _ pointB: MKMapPoint) {
        let first = QuantizedMapPoint(pointA)
        let second = QuantizedMapPoint(pointB)
        (start, end) = first < second ? (first, second) : (second, first)
    }
}

private struct HexCellEdge {
    let key: HexEdgeKey
    let start: CGPoint
    let end: CGPoint
}

private struct CollectedGeometry {
    var todayPath = CGMutablePath()
    var fillPaths: [HexState: CGMutablePath] = [:]
    var contested: [(path: CGPath, edges: [HexCellEdge])] = []
    var cellEdges: [(state: HexState, edges: [HexCellEdge])] = []
    var edgeStates: [HexEdgeKey: [HexState: Int]] = [:]
    var flipping: [(boundary: [CLLocationCoordinate2D], animation: (from: HexState, to: HexState))] = []
}

final class HexGridOverlayRenderer: MKOverlayRenderer {
    private static let flipDuration: CFTimeInterval = 0.5

    private let grid: HexGridService
    private var displayLink: CADisplayLink?

    private struct State {
        var snapshot = HexOwnershipSnapshot(states: [:])
        var mode: HexMapMode = .territory
        var previousSnapshot = HexOwnershipSnapshot(states: [:])
        var hasReceivedSnapshot = false
        var animationStart: CFTimeInterval = 0
        var aggregateCache: [Int: [HexCell: HexState]] = [:]
        var visitCache: [Int: Set<HexCell>] = [:]
        var changedCellsCache: [Int: [HexCell: (from: HexState, to: HexState)]] = [:]
    }

    private let state = OSAllocatedUnfairLock<State>(initialState: State())

    init(overlay: MKOverlay, grid: HexGridService) {
        self.grid = grid
        super.init(overlay: overlay)
    }

    deinit {
        displayLink?.invalidate()
    }

    func update(snapshot: HexOwnershipSnapshot, mode: HexMapMode) {
        let (changed, animate) = state.withLock { state -> (Bool, Bool) in
            let modeChanged = state.mode != mode
            state.mode = mode
            guard state.snapshot != snapshot || modeChanged else {
                return (false, false)
            }
            let animate = !modeChanged && mode == .territory
                && state.hasReceivedSnapshot && state.snapshot != snapshot
            if animate {
                state.previousSnapshot = state.snapshot
                state.animationStart = CACurrentMediaTime()
            } else {
                state.previousSnapshot = snapshot
            }
            state.hasReceivedSnapshot = true
            state.snapshot = snapshot
            state.aggregateCache = [:]
            state.visitCache = [:]
            state.changedCellsCache = [:]
            return (true, animate)
        }
        if animate {
            startDisplayLink()
        }
        if changed {
            setNeedsDisplay()
        }
    }

    private func startDisplayLink() {
        displayLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(animationTick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func animationTick() {
        let start = state.withLock { $0.animationStart }
        if CACurrentMediaTime() - start >= Self.flipDuration {
            displayLink?.invalidate()
            displayLink = nil
        }
        setNeedsDisplay()
    }

    override func canDraw(_ mapRect: MKMapRect, zoomScale: MKZoomScale) -> Bool {
        true
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let center = MKMapPoint(x: mapRect.midX, y: mapRect.midY)
        let latitude = center.coordinate.latitude
        guard let resolution = HexZoomPolicy.resolution(forZoomScale: zoomScale, latitude: latitude) else {
            return
        }

        let hexEdgeMeters = sqrt(HexZoomPolicy.averageHexagonAreaM2[resolution] / 2.598)
        let paddingPoints = hexEdgeMeters * 1.5 * MKMapPointsPerMeterAtLatitude(latitude)
        let paddedRect = mapRect.insetBy(dx: -paddingPoints, dy: -paddingPoints)
        let region = MKCoordinateRegion(paddedRect)

        let cells = grid.cells(in: region, resolution: resolution)
        let mode = state.withLock { $0.mode }
        let exploring = mode == .exploration
        let (states, visits) = aggregated(at: resolution, exploring: exploring)
        let changed = exploring ? [:] : changedCells(at: resolution)
        let elapsed = state.withLock { CACurrentMediaTime() - $0.animationStart }
        let progress = min(max(elapsed / Self.flipDuration, 0), 1)
        let geometry = collect(
            cells: cells, states: states, visits: visits, changed: changed,
            progress: progress, exploring: exploring
        )

        context.setLineWidth(1 / zoomScale)
        for (cellState, path) in geometry.fillPaths {
            guard let color = cellState.color else { continue }
            context.addPath(path)
            context.setFillColor(UIColor(color).withAlphaComponent(0.45).cgColor)
            context.fillPath()
        }
        context.setLineWidth(2 / zoomScale)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        let boundaryPaths = territoryBoundaryPaths(cellEdges: geometry.cellEdges, edgeStates: geometry.edgeStates)
        for (cellState, path) in boundaryPaths {
            guard cellState != .contested, let color = cellState.color else { continue }
            context.addPath(path)
            context.setStrokeColor(UIColor(color).cgColor)
            context.strokePath()
        }
        for item in geometry.contested {
            let outline = CGMutablePath()
            for edge in item.edges where isTerritoryBoundary(edge: edge, in: geometry.edgeStates) {
                outline.move(to: edge.start)
                outline.addLine(to: edge.end)
            }
            drawContested(path: item.path, outline: outline, zoomScale: zoomScale, in: context)
        }
        context.addPath(geometry.todayPath)
        context.setStrokeColor(UIColor.systemGreen.cgColor)
        context.setLineWidth(3 / zoomScale)
        context.strokePath()
        for item in geometry.flipping {
            drawFlip(
                boundary: item.boundary, animation: item.animation,
                progress: progress, zoomScale: zoomScale, in: context
            )
        }
    }

    private func collect(
        cells: [HexCell],
        states: [HexCell: HexState],
        visits: Set<HexCell>,
        changed: [HexCell: (from: HexState, to: HexState)],
        progress: Double,
        exploring: Bool
    ) -> CollectedGeometry {
        var geometry = CollectedGeometry()
        for cell in cells {
            let boundary = grid.boundary(of: cell)
            guard !boundary.isEmpty else { continue }
            if visits.contains(cell) {
                appendPath(to: &geometry.todayPath, boundary: boundary)
            }
            let cellState = states[cell] ?? .unclaimed
            if let animation = changed[cell], progress < 1 {
                geometry.flipping.append((boundary, animation))
            } else if exploring {
                guard cellState != .unclaimed else { continue }
                let fillState = cellState == .contested ? .owned : cellState
                var path = geometry.fillPaths[fillState] ?? CGMutablePath()
                appendPath(to: &path, boundary: boundary)
                geometry.fillPaths[fillState] = path
            } else if cellState != .unclaimed {
                let edges = cellEdges(boundary: boundary, state: cellState, edgeStates: &geometry.edgeStates)
                if cellState == .contested {
                    var path = CGMutablePath()
                    appendPath(to: &path, boundary: boundary)
                    geometry.contested.append((path, edges))
                } else {
                    var path = geometry.fillPaths[cellState] ?? CGMutablePath()
                    appendPath(to: &path, boundary: boundary)
                    geometry.fillPaths[cellState] = path
                }
                geometry.cellEdges.append((cellState, edges))
            }
        }
        return geometry
    }

    private func cellEdges(
        boundary: [CLLocationCoordinate2D],
        state cellState: HexState,
        edgeStates: inout [HexEdgeKey: [HexState: Int]]
    ) -> [HexCellEdge] {
        boundary.indices.map { index in
            let next = index == boundary.index(before: boundary.endIndex)
                ? boundary.startIndex
                : boundary.index(after: index)
            let pointA = MKMapPoint(boundary[index])
            let pointB = MKMapPoint(boundary[next])
            let key = HexEdgeKey(pointA, pointB)
            edgeStates[key, default: [:]][cellState, default: 0] += 1
            return HexCellEdge(key: key, start: point(for: pointA), end: point(for: pointB))
        }
    }

    private func territoryBoundaryPaths(
        cellEdges: [(state: HexState, edges: [HexCellEdge])],
        edgeStates: [HexEdgeKey: [HexState: Int]]
    ) -> [HexState: CGMutablePath] {
        var paths: [HexState: CGMutablePath] = [:]
        for (state, edges) in cellEdges {
            for edge in edges where isTerritoryBoundary(edge: edge, in: edgeStates) {
                let strokeState = edgeStates[edge.key]?.keys.max() ?? state
                let path = paths[strokeState] ?? CGMutablePath()
                path.move(to: edge.start)
                path.addLine(to: edge.end)
                paths[strokeState] = path
            }
        }
        return paths
    }

    private func isTerritoryBoundary(edge: HexCellEdge, in edgeStates: [HexEdgeKey: [HexState: Int]]) -> Bool {
        guard let neighbours = edgeStates[edge.key] else { return false }
        return neighbours.count > 1 || neighbours.values.reduce(0, +) == 1
    }

    private func changedCells(at resolution: Int) -> [HexCell: (from: HexState, to: HexState)] {
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

    private func drawFlip(
        boundary: [CLLocationCoordinate2D],
        animation: (from: HexState, to: HexState),
        progress: Double,
        zoomScale: MKZoomScale,
        in context: CGContext
    ) {
        let points = boundary.map { point(for: MKMapPoint($0)) }
        guard !points.isEmpty else { return }
        let center = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
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
            drawCaptureRing(boundary: boundary, center: center, progress: progress, zoomScale: zoomScale, in: context)
        }
        let pop = 1 + 0.15 * CGFloat(sin(progress * .pi))
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.scaleBy(x: max(scaleX, 0.01) * pop, y: pop)
        context.translateBy(x: -center.x, y: -center.y)
        var path = CGMutablePath()
        appendPath(to: &path, boundary: boundary)
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
    private func drawCaptureRing(
        boundary: [CLLocationCoordinate2D],
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
        appendPath(to: &hexPath, boundary: boundary)
        guard let ringPath = hexPath.copy(using: &transform) else { return }
        context.addPath(ringPath)
        context.setStrokeColor(UIColor.white.withAlphaComponent((1 - ringProgress) * 0.9).cgColor)
        context.setLineWidth((3 - ringProgress) / zoomScale)
        context.strokePath()
    }

    private func drawContested(path: CGPath, outline: CGPath, zoomScale: MKZoomScale, in context: CGContext) {
        let bounds = path.boundingBoxOfPath
        let padded = bounds.insetBy(dx: -2 / zoomScale, dy: -2 / zoomScale)
        let halves: [(UIColor, CGRect)] = [
            (UIColor(Color.red), CGRect(x: padded.minX, y: padded.minY,
                                       width: bounds.midX - padded.minX, height: padded.height)),
            (UIColor(Color.blue), CGRect(x: bounds.midX, y: padded.minY,
                                        width: padded.maxX - bounds.midX, height: padded.height))
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

    private func aggregated(at resolution: Int, exploring: Bool) -> ([HexCell: HexState], Set<HexCell>) {
        state.withLock { state in
            if let cached = state.aggregateCache[resolution], let visits = state.visitCache[resolution] {
                return (cached, visits)
            }
            let result = exploring
                ? state.snapshot.aggregatedPersonal(at: resolution, grid: grid)
                : state.snapshot.aggregated(at: resolution, grid: grid)
            let visits = state.snapshot.aggregatedVisits(at: resolution, grid: grid)
            state.aggregateCache[resolution] = result
            state.visitCache[resolution] = visits
            return (result, visits)
        }
    }

    private func appendPath(to path: inout CGMutablePath, boundary: [CLLocationCoordinate2D]) {
        for (index, coordinate) in boundary.enumerated() {
            let point = point(for: MKMapPoint(coordinate))
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
    }
}
