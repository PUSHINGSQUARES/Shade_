import XCTest
@testable import Shade_

@MainActor
final class OverlayFallbackControllerTests: XCTestCase {
    func testShowCreatesOneClickThroughWindowPerDisplay() {
        let displays = [
            OverlayDisplay(frame: NSRect(x: 0, y: 0, width: 640, height: 480)),
            OverlayDisplay(frame: NSRect(x: 640, y: 0, width: 800, height: 600))
        ]
        let controller = OverlayFallbackController(screenProvider: { displays })

        controller.show(appearance: OverlayFallbackAppearance(tintRed: 1, tintGreen: 0.9, tintBlue: 0.5, opacity: 0.25, dim: 0.15))

        XCTAssertEqual(controller.windowCount, 2)
        XCTAssertEqual(controller.windows.map(\.window.frame), displays.map(\.frame))
        XCTAssertTrue(controller.windows.allSatisfy { $0.window.ignoresMouseEvents })
    }

    func testHideDestroysOverlayWindows() {
        let controller = OverlayFallbackController(screenProvider: {
            [OverlayDisplay(frame: NSRect(x: 0, y: 0, width: 640, height: 480))]
        })

        controller.show(appearance: OverlayFallbackAppearance(tintRed: 1, tintGreen: 0.9, tintBlue: 0.5, opacity: 0.25, dim: 0.15))
        controller.hide()

        XCTAssertEqual(controller.windowCount, 0)
        XCTAssertFalse(controller.isShowing)
    }

    func testWindowUsesTransformCompatibleClickThroughConfiguration() throws {
        guard let screen = NSScreen.main else {
            throw XCTSkip("No screen available")
        }

        let overlayWindow = OverlayFallbackWindow(
            display: OverlayDisplay(screen: screen),
            appearance: OverlayFallbackAppearance(tintRed: 1, tintGreen: 0.9, tintBlue: 0.5, opacity: 0.25, dim: 0.15)
        )

        XCTAssertEqual(overlayWindow.window.styleMask, [.borderless])
        XCTAssertEqual(overlayWindow.window.level, .screenSaver)
        XCTAssertTrue(overlayWindow.window.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(overlayWindow.window.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertTrue(overlayWindow.window.collectionBehavior.contains(.stationary))
        XCTAssertTrue(overlayWindow.window.ignoresMouseEvents)
        XCTAssertFalse(overlayWindow.window.isOpaque)
    }

    func testAppearanceDerivesTintAndDimLayers() {
        let appearance = OverlayFallbackAppearance(tintRed: 1, tintGreen: 0.9, tintBlue: 0.5, opacity: 0.25, dim: 0.35)

        XCTAssertEqual(appearance.tintColor.alphaComponent, 0.25, accuracy: 0.001)
        XCTAssertEqual(appearance.dimColor, NSColor.black.withAlphaComponent(0.35))
    }

    func testWindowCoversItsScreenInGlobalCoordinates() throws {
        let screens = NSScreen.screens
        try XCTSkipUnless(screens.count >= 2, "Needs 2+ displays to exercise non-primary placement")

        for screen in screens {
            let overlayWindow = OverlayFallbackWindow(
                display: OverlayDisplay(screen: screen),
                appearance: OverlayFallbackAppearance(tintRed: 1, tintGreen: 0.9, tintBlue: 0.5, opacity: 0.25, dim: 0.15)
            )

            XCTAssertEqual(
                overlayWindow.window.frame,
                screen.frame,
                "Overlay window must cover its screen using global coordinates, not screen-relative ones"
            )
        }
    }

    func testWindowAppliesMaskWhenProtectedRectsExist() {
        let overlayWindow = OverlayFallbackWindow(
            display: OverlayDisplay(frame: NSRect(x: 0, y: 0, width: 640, height: 480)),
            appearance: OverlayFallbackAppearance(
                tintRed: 1,
                tintGreen: 0.9,
                tintBlue: 0.5,
                opacity: 0.25,
                dim: 0.15,
                clearRects: [NSRect(x: 100, y: 80, width: 240, height: 180)]
            )
        )

        XCTAssertNotNil(overlayWindow.tintMaskLayer)
        XCTAssertNotNil(overlayWindow.dimMaskLayer)
        XCTAssertEqual(overlayWindow.tintMaskLayer?.fillRule, .evenOdd)
        XCTAssertEqual(overlayWindow.dimMaskLayer?.fillRule, .evenOdd)
    }

    func testWindowClearsMaskWhenProtectedRectsAreRemoved() {
        let overlayWindow = OverlayFallbackWindow(
            display: OverlayDisplay(frame: NSRect(x: 0, y: 0, width: 640, height: 480)),
            appearance: OverlayFallbackAppearance(
                tintRed: 1,
                tintGreen: 0.9,
                tintBlue: 0.5,
                opacity: 0.25,
                dim: 0.15,
                clearRects: [NSRect(x: 100, y: 80, width: 240, height: 180)]
            )
        )

        overlayWindow.update(appearance: OverlayFallbackAppearance(tintRed: 1, tintGreen: 0.9, tintBlue: 0.5, opacity: 0.25, dim: 0.15))

        XCTAssertNil(overlayWindow.tintMaskLayer)
        XCTAssertNil(overlayWindow.dimMaskLayer)
    }

    // MARK: - Resolved overlay tint tests

    func testWarmthStateProducesWarmTintFromResolver() {
        let state = AppState(userDefaults: UserDefaults(suiteName: "testWarmthResolver-\(UUID())")!)
        state.setPreset(.deepCut)

        let appearance = OverlayFallbackAppearance(state: state)
        let expected = OverlayTintResolver.resolve(state.overlayTintInputs)

        XCTAssertEqual(appearance.tintRed, expected.red, accuracy: 0.001)
        XCTAssertEqual(appearance.tintGreen, expected.green, accuracy: 0.001)
        XCTAssertEqual(appearance.tintBlue, expected.blue, accuracy: 0.001)
        XCTAssertEqual(appearance.opacity, expected.strength, accuracy: 0.001)
        XCTAssertEqual(appearance.dim, expected.dim, accuracy: 0.001)
        XCTAssertLessThan(appearance.tintBlue, appearance.tintRed, "Warm tint cuts blue below red")
    }

    func testCustomColourStateChangesTint() {
        let state = AppState(userDefaults: UserDefaults(suiteName: "testCustomColour-\(UUID())")!)
        state.overlayUseCustomColour = true
        state.overlayHue = 0.0
        let red = OverlayFallbackAppearance(state: state)

        state.overlayHue = 0.6667
        let blue = OverlayFallbackAppearance(state: state)

        XCTAssertGreaterThan(red.tintRed, blue.tintRed)
        XCTAssertGreaterThan(blue.tintBlue, red.tintBlue)
    }
}
