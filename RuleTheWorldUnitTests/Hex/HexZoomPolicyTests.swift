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
        #expect(HexZoomPolicy.resolution(for: region(span: 0.02)) == 9)
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
