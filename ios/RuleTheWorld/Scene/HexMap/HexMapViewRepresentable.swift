import MapKit
import SwiftUI

struct HexMapViewRepresentable: UIViewRepresentable {
    let initialRegion: MKCoordinateRegion
    let snapshot: HexOwnershipSnapshot
    let mode: HexMapMode
    let grid: HexGridService
    let userStatus: UserMapStatus?
    let selectedRegion: MapRegionSelection?
    let powerUpEffect: PowerUpEffect?
    let reduceMotion: Bool
    let animationsEnabled: Bool
    let powerUpTopInset: CGFloat
    let powerUpBottomInset: CGFloat
    let onPowerUpWindowProvider: (@escaping () -> [HexCell]?) -> Void
    let onCameraChange: (MKZoomScale, MKCoordinateRegion, Double) -> Void
    let onTap: (CLLocationCoordinate2D) -> Void

    func makeUIView(context: Context) -> MKMapView {

        let config = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        config.pointOfInterestFilter = .excludingAll
        config.showsTraffic = false

        let mapView = MKMapView()
        configurePresentation(context.coordinator)
        mapView.delegate = context.coordinator
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsUserLocation = true
        mapView.preferredConfiguration = config
        mapView.setRegion(initialRegion, animated: false)
        mapView.addOverlay(HexGridOverlay(), level: .aboveRoads)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tap)
        let coordinator = context.coordinator
        onPowerUpWindowProvider { [weak mapView, weak coordinator] in
            guard let mapView, let coordinator else { return nil }
            return coordinator.powerUpWindow(in: mapView)
        }
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.onCameraChange = onCameraChange
        context.coordinator.onTap = onTap
        configurePresentation(context.coordinator)
        context.coordinator.updateRenderer()
        context.coordinator.apply(status: userStatus, to: mapView)
        context.coordinator.apply(region: selectedRegion, to: mapView)
    }

    private func configurePresentation(_ coordinator: Coordinator) {
        coordinator.powerUpTopInset = powerUpTopInset
        coordinator.powerUpBottomInset = powerUpBottomInset
        coordinator.snapshot = snapshot
        coordinator.mode = mode
        coordinator.powerUpEffect = powerUpEffect
        coordinator.reduceMotion = reduceMotion
        coordinator.animationsEnabled = animationsEnabled
    }

    static func dismantleUIView(_ mapView: MKMapView, coordinator: Coordinator) {
        coordinator.onCameraChange = nil
        coordinator.onTap = nil
        coordinator.renderer?.stopAnimations()
        mapView.delegate = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(grid: grid)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onCameraChange: ((MKZoomScale, MKCoordinateRegion, Double) -> Void)?
        var onTap: ((CLLocationCoordinate2D) -> Void)?

        var snapshot = HexOwnershipSnapshot(states: [:])
        var mode: HexMapMode = .territory
        var powerUpEffect: PowerUpEffect?
        var reduceMotion = false
        var animationsEnabled = true

        func updateRenderer() {
            renderer?.updatePresentation(
                effect: powerUpEffect, reduceMotion: reduceMotion, animationsEnabled: animationsEnabled
            )
            renderer?.update(snapshot: snapshot, mode: mode)
        }

        var powerUpTopInset: CGFloat = 0
        var powerUpBottomInset: CGFloat = 0

        func powerUpWindow(in mapView: MKMapView) -> [HexCell]? {
            let safeBounds = mapView.bounds.inset(by: mapView.safeAreaInsets)
            let rect = CGRect(
                x: safeBounds.minX, y: safeBounds.minY + powerUpTopInset,
                width: safeBounds.width,
                height: max(0, safeBounds.height - powerUpTopInset - powerUpBottomInset)
            )
            guard rect.width > 0, rect.height > 0 else { return [] }
            let region = mapView.convert(rect, toRegionFrom: mapView)
            return grid.cells(in: region, resolution: HexGridService.baseResolution).filter { cell in
                let boundary = grid.boundary(of: cell)
                return !boundary.isEmpty && boundary.allSatisfy {
                    rect.contains(mapView.convert($0, toPointTo: mapView))
                }
            }
        }

        private(set) var renderer: HexGridOverlayRenderer?
        private let grid: HexGridService
        private var hasCenteredOnUser = false
        private let statusView = UserStatusAnnotationView(frame: .zero)
        private var status: UserMapStatus?
        private var selectedRegion: MapRegionSelection?
        private var countryOverlay: MKMultiPolygon?

        init(grid: HexGridService) {
            self.grid = grid
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKMultiPolygon {
                let renderer = MKMultiPolygonRenderer(multiPolygon: polygon)
                let ink = UIColor(red: 0.3, green: 0.18, blue: 0.11, alpha: 1)
                renderer.fillColor = UIColor(red: 0.94, green: 0.81, blue: 0.55, alpha: 0.08)
                renderer.strokeColor = ink.withAlphaComponent(0.75)
                renderer.lineWidth = 2
                return renderer
            }
            guard overlay is HexGridOverlay else { return MKOverlayRenderer(overlay: overlay) }
            if let renderer {
                return renderer
            }
            let renderer = HexGridOverlayRenderer(overlay: overlay, grid: grid)
            self.renderer = renderer
            updateRenderer()
            return renderer
        }

        func apply(region: MapRegionSelection?, to mapView: MKMapView) {
            guard region != selectedRegion else { return }
            selectedRegion = region
            if let countryOverlay {
                mapView.removeOverlay(countryOverlay)
                self.countryOverlay = nil
            }
            guard let region else { return }
            let polygons = region.boundary.polygons.map { polygon in
                let holes = polygon.holes.map { makePolygon(ring: $0) }
                return makePolygon(ring: polygon.exterior, holes: holes)
            }
            let overlay = MKMultiPolygon(polygons)
            countryOverlay = overlay
            mapView.addOverlay(overlay, level: .aboveRoads)
        }

        private func makePolygon(ring: MapRegionBoundary.Ring, holes: [MKPolygon] = []) -> MKPolygon {
            let coordinates = ring.points.map {
                CLLocationCoordinate2D(
                    latitude: min(85.05112878, max(-85.05112878, $0.latitude)), longitude: $0.longitude
                )
            }
            return MKPolygon(coordinates: coordinates, count: coordinates.count, interiorPolygons: holes)
        }

        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            reportCamera(mapView)
            reapplyStatus(mapView)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            reportCamera(mapView)
        }

        func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
            reapplyStatus(mapView)
        }

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            guard !hasCenteredOnUser,
                  let location = userLocation.location,
                  CLLocationCoordinate2DIsValid(location.coordinate) else { return }
            hasCenteredOnUser = true
            let region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            mapView.setRegion(region, animated: true)
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let mapView = recognizer.view as? MKMapView else { return }
            let coordinate = mapView.convert(recognizer.location(in: mapView), toCoordinateFrom: mapView)
            onTap?(coordinate)
        }

        func apply(status: UserMapStatus?, to mapView: MKMapView) {
            self.status = status
            reapplyStatus(mapView)
        }

        private func reapplyStatus(_ mapView: MKMapView) {
            statusView.isHidden = status == nil
            guard let status,
                  let userLocationView = mapView.view(for: mapView.userLocation) else { return }
            if statusView.superview !== userLocationView {
                statusView.removeFromSuperview()
                userLocationView.addSubview(statusView)
            }
            statusView.center = CGPoint(x: userLocationView.bounds.midX, y: userLocationView.bounds.midY)
            statusView.apply(status: status, mapHeading: mapView.camera.heading)
        }

        private func reportCamera(_ mapView: MKMapView) {
            let width = mapView.visibleMapRect.width
            guard width > 0, mapView.bounds.width > 0 else { return }
            let zoomScale = mapView.bounds.width / width
            let center = mapView.centerCoordinate
            let visibleWidthMeters = width * MKMetersPerMapPointAtLatitude(center.latitude)
            onCameraChange?(zoomScale, MKCoordinateRegion(mapView.visibleMapRect), visibleWidthMeters)
        }
    }
}
