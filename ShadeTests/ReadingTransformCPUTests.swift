import XCTest
@testable import Shade_

final class ReadingTransformCPUTests: XCTestCase {
    func testClampsParameters() {
        let parameters = ReadingTransformParameters(
            intensity: 2,
            blueReduction: -1,
            dim: 1.5,
            contrastProtect: true
        )

        XCTAssertEqual(parameters.clamped.intensity, 1, accuracy: 0.001)
        XCTAssertEqual(parameters.clamped.blueReduction, 0, accuracy: 0.001)
        XCTAssertEqual(parameters.clamped.dim, 0.8, accuracy: 0.001)
    }

    func testClampsNonFiniteParametersToSafeDefaults() {
        let parameters = ReadingTransformParameters(
            intensity: .nan,
            blueReduction: .nan,
            dim: .nan,
            contrastProtect: true
        )

        let clamped = parameters.clamped

        XCTAssertTrue(clamped.intensity.isFinite)
        XCTAssertTrue(clamped.blueReduction.isFinite)
        XCTAssertTrue(clamped.dim.isFinite)
        XCTAssertEqual(clamped.intensity, 0, accuracy: 0.001)
        XCTAssertEqual(clamped.blueReduction, 0, accuracy: 0.001)
        XCTAssertEqual(clamped.dim, 0, accuracy: 0.001)
    }

    func testTransformReducesBlueDominantWhiteWithoutCrushingLuminance() {
        let input = RGBPixel(red: 0.92, green: 0.95, blue: 1.0)
        let parameters = ReadingTransformParameters(
            intensity: 0.6,
            blueReduction: 0.7,
            dim: 0.0,
            contrastProtect: true
        )

        let output = ReadingTransformCPU.apply(input, parameters: parameters)

        XCTAssertLessThan(output.blue, input.blue)
        XCTAssertGreaterThan(output.red, input.red - 0.08)
        XCTAssertGreaterThan(output.green, input.green - 0.08)
        XCTAssertEqual(output.luminance, input.luminance, accuracy: 0.08)
    }

    func testContrastProtectPreservesSaturatedBlueLuminanceWithoutUpperClipping() {
        let input = RGBPixel(red: 0, green: 0, blue: 1)
        let parameters = ReadingTransformParameters(
            intensity: 1,
            blueReduction: 1,
            dim: 0,
            contrastProtect: true
        )

        let output = ReadingTransformCPU.apply(input, parameters: parameters)

        XCTAssertEqual(output.luminance, input.luminance, accuracy: 0.005)
        XCTAssertLessThan(output.red, 0.99)
        XCTAssertLessThan(output.green, 0.99)
        XCTAssertLessThan(output.blue, 0.99)
    }

    func testDimReducesAllChannelsAfterTransform() {
        let input = RGBPixel(red: 0.5, green: 0.5, blue: 0.5)
        let parameters = ReadingTransformParameters(
            intensity: 0,
            blueReduction: 0,
            dim: 0.2,
            contrastProtect: true
        )

        let output = ReadingTransformCPU.apply(input, parameters: parameters)

        XCTAssertEqual(output.red, 0.4, accuracy: 0.001)
        XCTAssertEqual(output.green, 0.4, accuracy: 0.001)
        XCTAssertEqual(output.blue, 0.4, accuracy: 0.001)
    }

    func testTransformWithNonFiniteParametersReturnsFiniteOutput() {
        let input = RGBPixel(red: 0.2, green: 0.4, blue: 0.8)
        let parameters = ReadingTransformParameters(
            intensity: .nan,
            blueReduction: .nan,
            dim: .nan,
            contrastProtect: true
        )

        let output = ReadingTransformCPU.apply(input, parameters: parameters)

        XCTAssertTrue(output.red.isFinite)
        XCTAssertTrue(output.green.isFinite)
        XCTAssertTrue(output.blue.isFinite)
    }
}
