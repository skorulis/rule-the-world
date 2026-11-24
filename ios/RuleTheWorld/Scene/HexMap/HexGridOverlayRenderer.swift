import MapKit
import SwiftUI
import os

final class HexGridOverlayRenderer: MKOverlayRenderer {
    private static let flipDuration: CFTimeInterval = 0.5

    private let grid: HexGridService
    private var displayLink: CADisplayLink?

    private struct State {
        var snapshot = HexOwnershipSnapshot(states: [:])
        var previousSnapshot = HexOwnershipSnapshot(states: [:])
        var hasReceivedSnapshot = false
        var animationStart: CFTimeInterval = 0
        var showGrid = true
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

    func update(snapshot: HexOwnershipSnapshot, showGrid: Bool) {
        let (changed, animate) = state.withLock { state -> (Bool, Bool) in
            guard state.snapshot != snapshot || state.showGrid != showGrid else {
                return (false, false)
            }
            let animate = state.hasReceivedSnapshot && state.snapshot != snapshot
            if animate {
                state.previousSnapshot = state.snapshot
                state.animationStart = CACurrentMediaTime()
            } else {
                state.previousSnapshot = snapshot
            }
            state.hasReceivedSnapshot = true
            state.snapshot = snapshot
            state.showGrid = showGrid
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
        let (states, visits) = aggregated(at: resolution)
        let changed = changedCells(at: resolution)
        let elapsed = state.withLock { CACurrentMediaTime() - $0.animationStart }
        let progress = min(max(elapsed / Self.flipDuration, 0), 1)
        var todayPath = CGMutablePath()

        var unclaimedPath = CGMutablePath()
        var ownedPaths: [HexState: (fill: CGMutablePath, stroke: CGMutablePath)] = [:]
        var flipping: [(boundary: [CLLocationCoordinate2D], animation: (from: HexState, to: HexState))] = []
        for cell in cells {
            let boundary = grid.boundary(of: cell)
            guard !boundary.isEmpty else { continue }
            if visits.contains(cell) {
                appendPath(to: &todayPath, boundary: boundary)
            }
            let cellState = states[cell] ?? .unclaimed
            if let animation = changed[cell], progress < 1 {
                flipping.append((boundary, animation))
            } else if cellState == .unclaimed {
                appendPath(to: &unclaimedPath, boundary: boundary)
            } else {
                let paths = ownedPaths[cellState] ?? (CGMutablePath(), CGMutablePath())
                var fill = paths.fill
                var stroke = paths.stroke
                appendPath(to: &fill, boundary: boundary)
                appendPath(to: &stroke, boundary: boundary)
                ownedPaths[cellState] = (fill, stroke)
            }
        }

        context.setLineWidth(1 / zoomScale)
        let showGrid = state.withLock { $0.showGrid }
        if showGrid {
            context.addPath(unclaimedPath)
            context.setStrokeColor(UIColor.gray.withAlphaComponent(0.6).cgColor)
            context.strokePath()
        }
        for (cellState, paths) in ownedPaths {
            guard let color = cellState.color else { continue }
            let uiColor = UIColor(color)
            context.addPath(paths.fill)
            context.setFillColor(uiColor.withAlphaComponent(0.45).cgColor)
            context.fillPath()
            context.addPath(paths.stroke)
            context.setStrokeColor(uiColor.cgColor)
            context.strokePath()
        }
        context.addPath(todayPath)
        context.setStrokeColor(UIColor.systemGreen.cgColor)
        context.setLineWidth(3 / zoomScale)
        context.strokePath()
        for item in flipping {
            drawFlip(boundary: item.boundary, animation: item.animation, progress: progress, zoomScale: zoomScale, in: context)
        }
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
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.scaleBy(x: max(scaleX, 0.01), y: 1)
        context.translateBy(x: -center.x, y: -center.y)
        var path = CGMutablePath()
        appendPath(to: &path, boundary: boundary)
        context.addPath(path)
        let uiColor = shown.color.map(UIColor.init) ?? .gray
        context.setFillColor(uiColor.withAlphaComponent(shown == .unclaimed ? 0 : 0.45).cgColor)
        context.setStrokeColor(uiColor.cgColor)
        context.setLineWidth(1 / zoomScale)
        context.drawPath(using: .fillStroke)
        context.restoreGState()
    }

    private func aggregated(at resolution: Int) -> ([HexCell: HexState], Set<HexCell>) {
        state.withLock { state in
            if let cached = state.aggregateCache[resolution], let visits = state.visitCache[resolution] {
                return (cached, visits)
            }
            let result = state.snapshot.aggregated(at: resolution, grid: grid)
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
