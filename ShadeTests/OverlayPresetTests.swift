import XCTest
@testable import Shade_

final class OverlayPresetTests: XCTestCase {
    func testWarmthPresetsAreNotCustomColour() {
        for preset in [OverlayPreset.gentle, .balanced, .deepCut] {
            let values = preset.values
            XCTAssertNotNil(values)
            XCTAssertFalse(values!.useCustomColour, "\(preset) should be a warmth preset")
        }
    }

    func testReadingPresetsUseCustomColour() {
        for preset in [OverlayPreset.blue, .cream, .green, .rose, .grey] {
            let values = preset.values
            XCTAssertNotNil(values)
            XCTAssertTrue(values!.useCustomColour, "\(preset) should be a reading preset")
        }
    }

    func testCustomHasNoValues() {
        XCTAssertNil(OverlayPreset.custom.values)
    }

    func testDeepCutCutsMoreBlueThanGentle() {
        XCTAssertGreaterThan(OverlayPreset.deepCut.values!.blueCut, OverlayPreset.gentle.values!.blueCut)
    }

    func testGentleLeansOnDimMoreThanDeepCut() {
        XCTAssertGreaterThan(OverlayPreset.gentle.values!.dim, OverlayPreset.deepCut.values!.dim)
    }

    func testGreyIsDesaturated() {
        XCTAssertEqual(OverlayPreset.grey.values!.saturation, 0.0, accuracy: 0.001)
    }

    func testPresentationGroupsAndTitles() {
        XCTAssertEqual(OverlayPresetPresentation.warmthPresets, [.gentle, .balanced, .deepCut])
        XCTAssertEqual(OverlayPresetPresentation.readingPresets, [.blue, .cream, .green, .rose, .grey])
        XCTAssertEqual(OverlayPresetPresentation.title(.deepCut), "Deep Cut")
        XCTAssertEqual(OverlayPresetPresentation.title(.cream), "Cream")
        XCTAssertEqual(OverlayPresetPresentation.title(.custom), "Custom")
    }
}
