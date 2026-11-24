import MapKit
import SwiftUI

struct HexMapViewRepresentable: UIViewRepresentable {
    let initialRegion: MKCoordinateRegion
    let snapshot: HexOwnershipSnapshot
    let grid: HexGridService
    let userStatus: UserMapStatus?
    let selectedRegion: MapRegionSelection?
    let onCameraChange: (MKZoomScale, CLLocationCoordinate2D, Double) -> Void
    let onTap: (CLLocationCoordinate2D) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsUserLocation = true
        mapView.setRegion(initialRegion, animated: false)
        mapView.addOverlay(HexGridOverlay(), level: .aboveRoads)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tap)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.onCameraChange = onCameraChange
        context.coordinator.onTap = onTap
        context.coordinator.renderer?.update(snapshot: snapshot)
        context.coordinator.apply(status: userStatus, to: mapView)
        context.coordinator.apply(region: selectedRegion, to: mapView)
    }

    static func dismantleUIView(_ mapView: MKMapView, coordinator: Coordinator) {
        coordinator.onCameraChange = nil
        coordinator.onTap = nil
        mapView.delegate = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(grid: grid)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onCameraChange: ((MKZoomScale, CLLocationCoordinate2D, Double) -> Void)?
        var onTap: ((CLLocationCoordinate2D) -> Void)?

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
                renderer.fillColor = mapView.tintColor.withAlphaComponent(0.05)
                renderer.strokeColor = mapView.tintColor
                renderer.lineWidth = 2
                return renderer
            }
            guard overlay is HexGridOverlay else { return MKOverlayRenderer(overlay: overlay) }
            if let renderer {
                return renderer
            }
            let renderer = HexGridOverlayRenderer(overlay: overlay, grid: grid)
            self.renderer = renderer
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
            onCameraChange?(zoomScale, center, visibleWidthMeters)
        }
    }
}
