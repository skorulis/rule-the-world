import CoreLocation
import MapKit
import Testing
@testable import RuleTheWorld

struct HexZoomPolicyTests {
    private func region(span: Double) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -33.89, longitude: 151.19),
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
    }

    @Test func neighbourhoodReturnsBaseResolution() {
        #expect(HexZoomPolicy.resolution(for: region(span: 0.018)) == 10)
    }

    @Test func cityReturnsCoarserResolution() {
        let resolution = HexZoomPolicy.resolution(for: region(span: 1.0))
        #expect(resolution != nil)
        #expect(resolution! < 9)
        #expect(resolution! >= 4)
    }

    @Test func continentReturnsNil() {
        #expect(HexZoomPolicy.resolution(for: region(span: 60)) == nil)
    }
}

struct HexZoomScaleTests {
    private let sydney = CLLocationDegrees(-33.89)
    private let screen = CGSize(width: 400, height: 850)

    @Test func zoomScaleForTwoKilometreScreenGivesBaseResolution() {
        let metersPerPoint = 2_000 / screen.height
        let zoomScale = 1 / (metersPerPoint * MKMapPointsPerMeterAtLatitude(sydney))
        #expect(HexZoomPolicy.resolution(forZoomScale: zoomScale, latitude: sydney, screenSize: screen) == 10)
    }

    @Test func thirtyTwoTimesSmallerZoomScaleGivesCoarserResolution() {
        let metersPerPoint = 2_000 / screen.height
        let zoomScale = 1 / (metersPerPoint * MKMapPointsPerMeterAtLatitude(sydney)) / 32
        let resolution = HexZoomPolicy.resolution(forZoomScale: zoomScale, latitude: sydney, screenSize: screen)
        #expect(resolution != nil)
        #expect((4...8).contains(resolution!))
    }

    @Test func tinyZoomScaleGivesNil() {
        #expect(HexZoomPolicy.resolution(forZoomScale: 1 / 1_000_000, latitude: sydney, screenSize: screen) == nil)
    }
}
