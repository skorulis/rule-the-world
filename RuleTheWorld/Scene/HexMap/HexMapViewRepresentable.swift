import MapKit
import SwiftUI

struct HexMapViewRepresentable: UIViewRepresentable {
    let initialRegion: MKCoordinateRegion
    let snapshot: HexOwnershipSnapshot
    let showGrid: Bool
    let grid: HexGridService
    let onCameraChange: (MKZoomScale, CLLocationDegrees) -> Void
    let onTap: (CLLocationCoordinate2D) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsUserLocation = true
        mapView.setRegion(initialRegion, animated: false)
        mapView.addOverlay(HexGridOverlay(), level: .aboveRoads)
        #if DEBUG
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tap)
        #endif
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.onCameraChange = onCameraChange
        #if DEBUG
        context.coordinator.onTap = onTap
        #endif
        context.coordinator.renderer?.update(snapshot: snapshot, showGrid: showGrid)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(grid: grid)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onCameraChange: ((MKZoomScale, CLLocationDegrees) -> Void)?
        var onTap: ((CLLocationCoordinate2D) -> Void)?

        private(set) var renderer: HexGridOverlayRenderer?
        private let grid: HexGridService
        private var hasCenteredOnUser = false

        init(grid: HexGridService) {
            self.grid = grid
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let renderer {
                return renderer
            }
            let renderer = HexGridOverlayRenderer(overlay: overlay, grid: grid)
            self.renderer = renderer
            return renderer
        }

        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            reportCamera(mapView)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            reportCamera(mapView)
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

        #if DEBUG
        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let mapView = recognizer.view as? MKMapView else { return }
            let coordinate = mapView.convert(recognizer.location(in: mapView), toCoordinateFrom: mapView)
            onTap?(coordinate)
        }
        #endif

        private func reportCamera(_ mapView: MKMapView) {
            let width = mapView.visibleMapRect.width
            guard width > 0, mapView.bounds.width > 0 else { return }
            let zoomScale = mapView.bounds.width / width
            onCameraChange?(zoomScale, mapView.centerCoordinate.latitude)
        }
    }
}
