import XCTest
@testable import Shade_

final class LocationProviderTests: XCTestCase {
    func testSuccessProducesScheduleLocation() async {
        let fake = FakeLocationProvider(result: .success(
            ScheduleLocation(label: "Current location", latitude: 51.45, longitude: -2.59)
        ))
        let result = await fake.requestCurrentLocation()
        switch result {
        case .success(let loc):
            XCTAssertEqual(loc.label, "Current location")
            XCTAssertEqual(loc.latitude, 51.45, accuracy: 0.001)
        case .failure:
            XCTFail("expected success")
        }
    }

    func testDeniedSurfacesError() async {
        let fake = FakeLocationProvider(result: .failure(.denied))
        let result = await fake.requestCurrentLocation()
        if case .failure(let error) = result {
            XCTAssertEqual(error, .denied)
        } else {
            XCTFail("expected denial")
        }
    }
}

final class FakeLocationProvider: LocationProvider {
    let result: Result<ScheduleLocation, LocationError>
    init(result: Result<ScheduleLocation, LocationError>) { self.result = result }
    func requestCurrentLocation() async -> Result<ScheduleLocation, LocationError> { result }
}
