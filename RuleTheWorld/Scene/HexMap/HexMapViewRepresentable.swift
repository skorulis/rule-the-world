import MapKit
import SwiftUI

struct HexMapViewRepresentable: UIViewRepresentable {
    let initialRegion: MKCoordinateRegion
    let snapshot: HexOwnershipSnapshot
    let showGrid: Bool
    let grid: HexGridService
    let userStatus: UserMapStatus?
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
        context.coordinator.apply(status: userStatus, to: mapView)
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
        private var statusAnnotation: UserStatusAnnotation?
        private var status: UserMapStatus?

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
            reapplyStatus(mapView)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            reportCamera(mapView)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let statusAnnotation = annotation as? UserStatusAnnotation else {
                return nil
            }
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: UserStatusAnnotationView.reuseIdentifier
            ) as? UserStatusAnnotationView ?? UserStatusAnnotationView(
                annotation: statusAnnotation,
                reuseIdentifier: UserStatusAnnotationView.reuseIdentifier
            )
            if let status {
                view.apply(status: status, mapHeading: mapView.camera.heading)
            }
            return view
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

        func apply(status: UserMapStatus?, to mapView: MKMapView) {
            self.status = status
            guard let status else { return }
            let coordinate = CLLocationCoordinate2D(
                latitude: status.latitude,
                longitude: status.longitude
            )
            if let annotation = statusAnnotation {
                annotation.coordinate = coordinate
            } else {
                let annotation = UserStatusAnnotation(coordinate: coordinate)
                statusAnnotation = annotation
                mapView.addAnnotation(annotation)
            }
            reapplyStatus(mapView)
        }

        private func reapplyStatus(_ mapView: MKMapView) {
            guard let status, let annotation = statusAnnotation,
                  let view = mapView.view(for: annotation) as? UserStatusAnnotationView else { return }
            view.apply(status: status, mapHeading: mapView.camera.heading)
        }

        private func reportCamera(_ mapView: MKMapView) {
            let width = mapView.visibleMapRect.width
            guard width > 0, mapView.bounds.width > 0 else { return }
            let zoomScale = mapView.bounds.width / width
            onCameraChange?(zoomScale, mapView.centerCoordinate.latitude)
        }
    }
}
