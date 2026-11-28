import MapKit
import SwiftUI
import os

final class HexGridOverlayRenderer: MKOverlayRenderer {
    nonisolated private static let flipDuration: CFTimeInterval = 0.5

    let grid: HexGridService
    private var displayLink: CADisplayLink?

    struct State {
        var snapshot = HexOwnershipSnapshot(states: [:])
        var mode: HexMapMode = .territory
        var previousSnapshot = HexOwnershipSnapshot(states: [:])
        var hasReceivedSnapshot = false
        var animationStart: CFTimeInterval = 0
        var powerUps = PowerUpEffectPlayback()
        var reduceMotion = false
        var animationsEnabled = true
        var aggregateCache: [Int: (states: [HexCell: HexState], levels: [HexCell: Int])] = [:]
        var visitCache: [Int: Set<HexCell>] = [:]
        var changedCellsCache: [Int: [HexCell: (from: HexState, to: HexState)]] = [:]
    }

    let state = OSAllocatedUnfairLock<State>(initialState: State())

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
            let animate = state.animationsEnabled && !state.reduceMotion && !modeChanged && mode == .territory
                && state.hasReceivedSnapshot && state.snapshot != snapshot
            if animate {
                state.previousSnapshot = state.snapshot
                state.animationStart = CACurrentMediaTime()
            } else {
                state.previousSnapshot = snapshot
                state.animationStart = 0
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

    func updatePresentation(effect: PowerUpEffect?, reduceMotion: Bool, animationsEnabled: Bool) {
        state.withLock { state in
            state.reduceMotion = reduceMotion
            state.animationsEnabled = animationsEnabled
            state.powerUps.update(effect, at: .now, reduceMotion: reduceMotion, enabled: animationsEnabled)
            if reduceMotion || !animationsEnabled {
                state.animationStart = 0
                state.previousSnapshot = state.snapshot
                state.changedCellsCache = [:]
            }
        }
        animationTick()
    }

    func stopAnimations() {
        displayLink?.invalidate()
        displayLink = nil
        state.withLock { state in
            state.powerUps.stop()
            state.animationStart = 0
            state.previousSnapshot = state.snapshot
            state.changedCellsCache = [:]
            state.animationsEnabled = false
        }
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(
            target: HexAnimationTarget(renderer: self), selector: #selector(HexAnimationTarget.tick)
        )
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    fileprivate func animationTick() {
        let animate = state.withLock { state in
            state.powerUps.prune(at: .now, reduceMotion: state.reduceMotion)
            return state.animationsEnabled && (
                state.powerUps.needsAnimation || CACurrentMediaTime() - state.animationStart < Self.flipDuration
            )
        }
        if animate {
            startDisplayLink()
        } else {
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
        let hexEdge = hexEdgeMeters * MKMapPointsPerMeterAtLatitude(latitude)
        var paddingPoints = hexEdge * 1.5
        // Lifted tops extend beyond the cell footprint; pull in cells just offscreen.
        paddingPoints += Double(lift(HexElevationPolicy.maxLiftLevel, hexEdge: hexEdge))
        let paddedRect = mapRect.insetBy(dx: -paddingPoints, dy: -paddingPoints)
        let region = MKCoordinateRegion(paddedRect)

        let cells = grid.cells(in: region, resolution: resolution)
        let mode = state.withLock { $0.mode }
        let exploring = mode == .exploration
        let elapsed = state.withLock { CACurrentMediaTime() - $0.animationStart }
        let geometry = collect(
            input: CollectInput(
                cells: cells,
                aggregation: aggregated(at: resolution, exploring: exploring),
                changed: exploring ? [:] : changedCells(at: resolution),
                progress: min(max(elapsed / Self.flipDuration, 0), 1),
                exploring: exploring,
            ),
            hexEdge: hexEdge
        )

        for cell in geometry.cells {
            drawPlateau(
                cell: cell, geometry: geometry,
                hexEdge: hexEdge, zoomScale: zoomScale, in: context
            )
        }
        strokeOverlays(geometry: geometry, hexEdge: hexEdge, zoomScale: zoomScale, in: context)
        let progress = min(max(elapsed / Self.flipDuration, 0), 1)
        for item in geometry.flipping {
            drawFlip(cell: item, progress: progress, zoomScale: zoomScale, in: context)
        }
        if resolution == HexGridService.baseResolution {
            drawPowerUps(in: mapRect, hexEdge: hexEdge, zoomScale: zoomScale, context: context)
        }
    }
}

@MainActor
private final class HexAnimationTarget: NSObject {
    weak var renderer: HexGridOverlayRenderer?

    init(renderer: HexGridOverlayRenderer) {
        self.renderer = renderer
    }

    @objc func tick() {
        renderer?.animationTick()
    }
}
