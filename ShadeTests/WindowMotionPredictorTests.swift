import XCTest
@testable import Shade_

@MainActor
final class WindowMotionPredictorTests: XCTestCase {

    private func makeWindow(
        x: CGFloat, y: CGFloat,
        width: CGFloat = 400, height: CGFloat = 300,
        bundleID: String = "com.test.app"
    ) -> PassthroughWindowSnapshot {
        PassthroughWindowSnapshot(
            frame: NSRect(x: x, y: y, width: width, height: height),
            bundleIdentifier: bundleID,
            localizedAppName: "Test",
            windowTitle: "Window"
        )
    }

    private let rule = PassthroughApp(
        label: "Test",
        scope: .application,
        bundleIdentifier: "com.test.app"
    )

    // MARK: - Stationary window yields true position with rest margin

    func testStationaryWindowReturnsExactPositionWithRestMargin() {
        let predictor = WindowMotionPredictor()
        let config = MotionPredictionConfig(leadTimeSeconds: 0.016, restMargin: 3, motionMargin: 12)
        let window = makeWindow(x: 100, y: 200)

        _ = predictor.update(windows: [window], rules: [rule], timestamp: 0.0, config: config)
        let results = predictor.update(windows: [window], rules: [rule], timestamp: 0.016, config: config)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].frame.origin.x, 100, accuracy: 0.001)
        XCTAssertEqual(results[0].frame.origin.y, 200, accuracy: 0.001)
        XCTAssertEqual(results[0].margin, 3, accuracy: 0.001)
    }

    // MARK: - Moving window yields forward-led position

    func testMovingWindowExpandsRectForward() {
        let predictor = WindowMotionPredictor()
        let config = MotionPredictionConfig(leadTimeSeconds: 0.016, restMargin: 3, motionMargin: 12)

        _ = predictor.update(
            windows: [makeWindow(x: 100, y: 200)],
            rules: [rule], timestamp: 0.0, config: config
        )

        let moved = makeWindow(x: 200, y: 200)
        let results = predictor.update(
            windows: [moved], rules: [rule], timestamp: 0.016, config: config
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertLessThanOrEqual(results[0].frame.origin.x, 200)
        XCTAssertGreaterThan(results[0].frame.maxX, 200 + 400)
    }

    // MARK: - Margin grows with speed

    func testMarginGrowsWithSpeed() {
        let predictor = WindowMotionPredictor()
        let config = MotionPredictionConfig(leadTimeSeconds: 0.016, restMargin: 3, motionMargin: 12)

        _ = predictor.update(
            windows: [makeWindow(x: 100, y: 200)],
            rules: [rule], timestamp: 0.0, config: config
        )

        let moved = makeWindow(x: 600, y: 200)
        let results = predictor.update(
            windows: [moved], rules: [rule], timestamp: 0.016, config: config
        )

        XCTAssertGreaterThan(results[0].margin, 3)
    }

    // MARK: - Tint never inside window (trail-free invariant)

    func testPredictedRectAlwaysContainsOriginalWindow() {
        let predictor = WindowMotionPredictor()
        let config = MotionPredictionConfig(leadTimeSeconds: 0.016, restMargin: 3, motionMargin: 12)
        let display = OverlayDisplay(frame: NSRect(x: 0, y: 0, width: 1440, height: 900))

        _ = predictor.update(
            windows: [makeWindow(x: 100, y: 200)],
            rules: [rule], timestamp: 0.0, config: config
        )

        let currentWindow = makeWindow(x: 200, y: 200)
        let results = predictor.update(
            windows: [currentWindow], rules: [rule], timestamp: 0.016, config: config
        )

        let clearRects = PassthroughMask.clearRectsFromPredictions(
            for: display, predictions: results
        )

        XCTAssertEqual(clearRects.count, 1)
        let clearRect = clearRects[0]
        let windowLocalRect = NSRect(
            x: currentWindow.frame.origin.x - display.frame.origin.x,
            y: currentWindow.frame.origin.y - display.frame.origin.y,
            width: currentWindow.frame.width,
            height: currentWindow.frame.height
        )
        XCTAssertTrue(clearRect.contains(windowLocalRect),
            "Clear rect \(clearRect) must contain window rect \(windowLocalRect)")
    }

    // MARK: - Stopped window settles to exact position

    func testStoppedWindowSettlesToTruePosition() {
        let predictor = WindowMotionPredictor()
        let config = MotionPredictionConfig(leadTimeSeconds: 0.016, restMargin: 3, motionMargin: 12)

        _ = predictor.update(
            windows: [makeWindow(x: 100, y: 200)],
            rules: [rule], timestamp: 0.0, config: config
        )
        _ = predictor.update(
            windows: [makeWindow(x: 200, y: 200)],
            rules: [rule], timestamp: 0.016, config: config
        )

        let stopped = makeWindow(x: 200, y: 200)
        var results: [PredictedRect] = []
        for i in 2...60 {
            results = predictor.update(
                windows: [stopped],
                rules: [rule],
                timestamp: Double(i) * 0.016,
                config: config
            )
        }

        XCTAssertEqual(results[0].frame.origin.x, 200, accuracy: 0.1)
        XCTAssertEqual(results[0].frame.width, 400, accuracy: 0.1)
        XCTAssertEqual(results[0].margin, 3, accuracy: 0.1)
    }

    // MARK: - Zero lead time produces no prediction offset

    func testZeroLeadTimeProducesNoOffset() {
        let predictor = WindowMotionPredictor()
        let config = MotionPredictionConfig(leadTimeSeconds: 0.0, restMargin: 3, motionMargin: 12)

        _ = predictor.update(
            windows: [makeWindow(x: 100, y: 200)],
            rules: [rule], timestamp: 0.0, config: config
        )

        let moved = makeWindow(x: 200, y: 200)
        let results = predictor.update(
            windows: [moved], rules: [rule], timestamp: 0.016, config: config
        )

        XCTAssertEqual(results[0].frame.origin.x, 200, accuracy: 0.001)
    }

    // MARK: - Multiple windows tracked independently

    func testMultipleWindowsTrackedIndependently() {
        let predictor = WindowMotionPredictor()
        let config = MotionPredictionConfig(leadTimeSeconds: 0.016, restMargin: 3, motionMargin: 12)
        let rule2 = PassthroughApp(label: "Other", scope: .application, bundleIdentifier: "com.test.other")

        let w1 = makeWindow(x: 100, y: 200, bundleID: "com.test.app")
        let w2 = makeWindow(x: 500, y: 200, bundleID: "com.test.other")

        _ = predictor.update(windows: [w1, w2], rules: [rule, rule2], timestamp: 0.0, config: config)

        let w1Moved = makeWindow(x: 200, y: 200, bundleID: "com.test.app")
        let w2Still = makeWindow(x: 500, y: 200, bundleID: "com.test.other")

        let results = predictor.update(windows: [w1Moved, w2Still], rules: [rule, rule2], timestamp: 0.016, config: config)

        XCTAssertEqual(results.count, 2)

        let appResult = results.first { $0.frame.origin.x >= 100 && $0.frame.origin.x <= 200 }
        let otherResult = results.first { $0.frame.origin.x >= 400 }

        XCTAssertNotNil(appResult, "should have result for moved app window")
        XCTAssertNotNil(otherResult, "should have result for stationary other window")
        XCTAssertLessThanOrEqual(appResult!.frame.origin.x, 200)
        XCTAssertGreaterThan(appResult!.frame.maxX, 600, "union should extend past predicted position")
        XCTAssertEqual(otherResult!.frame.origin.x, 500, accuracy: 0.001)
    }

    // MARK: - First frame has no velocity

    func testFirstFrameHasZeroVelocity() {
        let predictor = WindowMotionPredictor()
        let config = MotionPredictionConfig(leadTimeSeconds: 0.016, restMargin: 3, motionMargin: 12)

        let results = predictor.update(
            windows: [makeWindow(x: 100, y: 200)],
            rules: [rule], timestamp: 0.0, config: config
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].frame.origin.x, 100, accuracy: 0.001)
        XCTAssertEqual(results[0].margin, 3, accuracy: 0.001)
    }

    // MARK: - Unmatched windows are ignored

    func testUnmatchedWindowsIgnored() {
        let predictor = WindowMotionPredictor()
        let config = MotionPredictionConfig.default

        let unmatchedWindow = makeWindow(x: 100, y: 200, bundleID: "com.other.app")
        let results = predictor.update(
            windows: [unmatchedWindow], rules: [rule], timestamp: 0.0, config: config
        )

        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Reset clears state

    func testResetClearsTrackedState() {
        let predictor = WindowMotionPredictor()
        let config = MotionPredictionConfig.default

        _ = predictor.update(
            windows: [makeWindow(x: 100, y: 200)],
            rules: [rule], timestamp: 0.0, config: config
        )

        predictor.reset()

        let results = predictor.update(
            windows: [makeWindow(x: 200, y: 200)],
            rules: [rule], timestamp: 0.016, config: config
        )

        XCTAssertEqual(results[0].frame.origin.x, 200, accuracy: 0.001)
        XCTAssertEqual(results[0].margin, 3, accuracy: 0.001)
    }
}
