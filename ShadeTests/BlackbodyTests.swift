import XCTest
@testable import Shade_

final class BlackbodyTests: XCTestCase {
    func test6500KIsApproximatelyWhite() {
        let c = Blackbody.rgb(kelvin: 6500)
        XCTAssertEqual(c.r, 1.0, accuracy: 0.001)
        XCTAssertEqual(c.g, 1.0, accuracy: 0.001)
        XCTAssertEqual(c.b, 1.0, accuracy: 0.001)
    }

    func testBlueDecreasesAsKelvinDecreases() {
        XCTAssertLessThan(Blackbody.rgb(kelvin: 2000).b, Blackbody.rgb(kelvin: 3000).b)
        XCTAssertLessThan(Blackbody.rgb(kelvin: 3000).b, Blackbody.rgb(kelvin: 6500).b)
    }

    func testRedStaysAtMaxAcrossRange() {
        XCTAssertEqual(Blackbody.rgb(kelvin: 1900).r, 1.0, accuracy: 0.001)
        XCTAssertEqual(Blackbody.rgb(kelvin: 4000).r, 1.0, accuracy: 0.001)
    }

    func testOutOfRangeKelvinClampsToEnds() {
        let cold = Blackbody.rgb(kelvin: 500)
        let warmEnd = Blackbody.rgb(kelvin: 1900)
        XCTAssertEqual(cold.b, warmEnd.b, accuracy: 0.001)

        let hot = Blackbody.rgb(kelvin: 12000)
        XCTAssertEqual(hot.b, 1.0, accuracy: 0.001)
    }

    func testInterpolatesBetweenTableEntries() {
        let mid = Blackbody.rgb(kelvin: 2400)
        let lo = Blackbody.rgb(kelvin: 2300)
        let hi = Blackbody.rgb(kelvin: 2500)
        XCTAssertGreaterThan(mid.b, lo.b)
        XCTAssertLessThan(mid.b, hi.b)
    }
}
