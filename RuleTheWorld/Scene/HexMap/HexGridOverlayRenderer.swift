import MapKit
import SwiftUI
import os

final class HexGridOverlayRenderer: MKOverlayRenderer {
    private let grid: HexGridService

    private struct State {
        var snapshot = HexOwnershipSnapshot(states: [:])
        var showGrid = true
        var aggregateCache: [Int: [HexCell: HexState]] = [:]
    }

    private let state = OSAllocatedUnfairLock<State>(initialState: State())

    init(overlay: MKOverlay, grid: HexGridService) {
        self.grid = grid
        super.init(overlay: overlay)
    }

    func update(snapshot: HexOwnershipSnapshot, showGrid: Bool) {
        let changed = state.withLock { state -> Bool in
            guard state.snapshot != snapshot || state.showGrid != showGrid else {
                return false
            }
            state.snapshot = snapshot
            state.showGrid = showGrid
            state.aggregateCache = [:]
            return true
        }
        if changed {
            setNeedsDisplay()
        }
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
        let states = aggregated(at: resolution)

        var unclaimedPath = CGMutablePath()
        var ownedPaths: [HexState: (fill: CGMutablePath, stroke: CGMutablePath)] = [:]
        for cell in cells {
            let boundary = grid.boundary(of: cell)
            guard !boundary.isEmpty else { continue }
            let cellState = states[cell] ?? .unclaimed
            if cellState == .unclaimed {
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
    }

    private func aggregated(at resolution: Int) -> [HexCell: HexState] {
        state.withLock { state in
            if let cached = state.aggregateCache[resolution] {
                return cached
            }
            let result = state.snapshot.aggregated(at: resolution, grid: grid)
            state.aggregateCache[resolution] = result
            return result
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
