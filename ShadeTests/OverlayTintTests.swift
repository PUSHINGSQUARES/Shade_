import XCTest
@testable import Shade_

final class OverlayTintTests: XCTestCase {
    private func warm(kelvin: Double, blueCut: Double, strength: Double = 0.2, dim: Double = 0.2) -> OverlayTintInputs {
        OverlayTintInputs(useCustomColour: false, kelvin: kelvin, blueCut: blueCut, hue: 0, saturation: 0, strength: strength, dim: dim)
    }

    func testWarmthPathAt6500NoCutIsWhite() {
        let t = OverlayTintResolver.resolve(warm(kelvin: 6500, blueCut: 0))
        XCTAssertEqual(t.red, 1.0, accuracy: 0.001)
        XCTAssertEqual(t.green, 1.0, accuracy: 0.001)
        XCTAssertEqual(t.blue, 1.0, accuracy: 0.001)
    }

    func testBlueCutReducesBlueOnWarmthPath() {
        let base = Blackbody.rgb(kelvin: 3000).b
        let t = OverlayTintResolver.resolve(warm(kelvin: 3000, blueCut: 0.9))
        XCTAssertEqual(t.blue, base * 0.1, accuracy: 0.001)
    }

    func testStrengthAndDimPassThroughClamped() {
        let t = OverlayTintResolver.resolve(warm(kelvin: 3000, blueCut: 0, strength: 1.5, dim: -0.2))
        XCTAssertEqual(t.strength, 1.0, accuracy: 0.001)
        XCTAssertEqual(t.dim, 0.0, accuracy: 0.001)
    }

    func testCustomColourPathIgnoresBlueCut() {
        // Pure blue hue, full saturation, with a large blueCut that must NOT apply.
        let inputs = OverlayTintInputs(useCustomColour: true, kelvin: 3000, blueCut: 0.9, hue: 0.6667, saturation: 1.0, strength: 0.2, dim: 0.1)
        let t = OverlayTintResolver.resolve(inputs)
        XCTAssertGreaterThan(t.blue, 0.9, "Reading-aid blue tint must keep its blue")
    }

    func testGreySaturationZeroIsNeutral() {
        let inputs = OverlayTintInputs(useCustomColour: true, kelvin: 2500, blueCut: 0, hue: 0.0, saturation: 0.0, strength: 0.15, dim: 0.15)
        let t = OverlayTintResolver.resolve(inputs)
        XCTAssertEqual(t.red, t.green, accuracy: 0.001)
        XCTAssertEqual(t.green, t.blue, accuracy: 0.001)
    }

    func testHueRedAtZero() {
        let inputs = OverlayTintInputs(useCustomColour: true, kelvin: 2500, blueCut: 0, hue: 0.0, saturation: 1.0, strength: 0.2, dim: 0.1)
        let t = OverlayTintResolver.resolve(inputs)
        XCTAssertEqual(t.red, 1.0, accuracy: 0.001)
        XCTAssertEqual(t.green, 0.0, accuracy: 0.001)
        XCTAssertEqual(t.blue, 0.0, accuracy: 0.001)
    }
}
