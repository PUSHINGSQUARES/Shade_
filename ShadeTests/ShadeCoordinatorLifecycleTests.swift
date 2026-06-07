import AppKit
import XCTest
@testable import Shade_

final class ShadeCoordinatorLifecycleTests: XCTestCase {
    @MainActor
    func testOverlayModeStartsOverlayWithoutStartingCapture() {
        let state = AppState(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        state.mode = .overlayFallback
        let overlayController = StubOverlayFallbackController()
        let coordinator = ShadeCoordinator(
            state: state,
            overlayController: overlayController
        )

        coordinator.setEnabled(true)

        XCTAssertEqual(overlayController.showCallCount, 1)
        XCTAssertTrue(overlayController.isShowing)
    }

    @MainActor
    func testOverlaySettingsUpdateWhileOverlayModeIsEnabled() {
        let state = AppState(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        state.mode = .overlayFallback
        let overlayController = StubOverlayFallbackController()
        let coordinator = ShadeCoordinator(
            state: state,
            overlayController: overlayController
        )

        coordinator.setEnabled(true)
        state.overlayHue = 0.42
        coordinator.overlaySettingsDidChange()

        XCTAssertEqual(overlayController.updateCallCount, 1)
    }

    @MainActor
    func testOverlaySettingsChangeKeepsPassthroughClearRects() {
        let state = AppState(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        state.mode = .overlayFallback
        state.addPassthroughApp(label: "Finder", bundleIdentifier: "com.apple.finder")
        let overlayController = StubOverlayFallbackController()
        let coordinator = ShadeCoordinator(
            state: state,
            overlayController: overlayController,
            passthroughWindowSnapshots: {
                [
                    PassthroughWindowSnapshot(
                        frame: NSRect(x: 50, y: 60, width: 200, height: 120),
                        bundleIdentifier: "com.apple.finder",
                        localizedAppName: "Finder",
                        windowTitle: "Desktop"
                    )
                ]
            },
            overlayDisplays: {
                [OverlayDisplay(frame: NSRect(x: 0, y: 0, width: 640, height: 480))]
            }
        )

        coordinator.setEnabled(true)
        state.overlayHue = 0.42
        coordinator.overlaySettingsDidChange()

        XCTAssertEqual(overlayController.updateCallCount, 1)
        XCTAssertEqual(
            overlayController.lastAppearance?.clearRects,
            [NSRect(x: 47.5, y: 57.5, width: 205, height: 125)]
        )
    }

    @MainActor
    func testPassthroughAppWhileOverlayShowingClearsWindowWithoutForegroundChange() {
        let state = AppState(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        state.mode = .overlayFallback
        let overlayController = StubOverlayFallbackController()
        let coordinator = ShadeCoordinator(
            state: state,
            overlayController: overlayController,
            passthroughWindowSnapshots: {
                [
                    PassthroughWindowSnapshot(
                        frame: NSRect(x: 50, y: 60, width: 200, height: 120),
                        bundleIdentifier: "com.apple.finder",
                        localizedAppName: "Finder",
                        windowTitle: "Desktop"
                    )
                ]
            },
            overlayDisplays: {
                [OverlayDisplay(frame: NSRect(x: 0, y: 0, width: 640, height: 480))]
            }
        )

        coordinator.setEnabled(true)
        XCTAssertEqual(overlayController.lastAppearance?.clearRects, [])

        state.addPassthroughApp(label: "Finder", bundleIdentifier: "com.apple.finder")
        coordinator.overlaySettingsDidChange()

        XCTAssertEqual(
            overlayController.lastAppearance?.clearRects,
            [NSRect(x: 47.5, y: 57.5, width: 205, height: 125)]
        )
    }

    @MainActor
    func testOverlayModeShowsWithPassthroughClearRectsWithoutChangingEnabledIntent() {
        let state = AppState(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        state.mode = .overlayFallback
        state.addPassthroughApp(label: "Finder", bundleIdentifier: "com.apple.finder")
        let overlayController = StubOverlayFallbackController()
        let coordinator = ShadeCoordinator(
            state: state,
            overlayController: overlayController,
            passthroughWindowSnapshots: {
                [
                    PassthroughWindowSnapshot(
                        frame: NSRect(x: 50, y: 60, width: 200, height: 120),
                        bundleIdentifier: "com.apple.finder",
                        localizedAppName: "Finder",
                        windowTitle: "Desktop"
                    )
                ]
            },
            overlayDisplays: {
                [OverlayDisplay(frame: NSRect(x: 0, y: 0, width: 640, height: 480))]
            }
        )

        coordinator.setEnabled(true)

        XCTAssertTrue(state.isTransformEnabled)
        XCTAssertEqual(overlayController.showCallCount, 1)
        XCTAssertEqual(overlayController.lastAppearance?.clearRects, [NSRect(x: 47.5, y: 57.5, width: 205, height: 125)])
    }

    @MainActor
    func testTrackerRunsOnlyWhenOverlayShowingWithPassthroughApps() {
        let state = AppState(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        state.mode = .overlayFallback
        let overlayController = StubOverlayFallbackController()
        let coordinator = ShadeCoordinator(
            state: state,
            overlayController: overlayController,
            passthroughWindowSnapshots: { [] },
            overlayDisplays: { [OverlayDisplay(frame: NSRect(x: 0, y: 0, width: 640, height: 480))] }
        )

        coordinator.setEnabled(true) // showing, but no passthrough apps yet
        XCTAssertFalse(coordinator.isTrackingPassthrough)

        state.addPassthroughApp(label: "Finder", bundleIdentifier: "com.apple.finder")
        coordinator.overlaySettingsDidChange()
        XCTAssertTrue(coordinator.isTrackingPassthrough)

        coordinator.setEnabled(false) // overlay hidden
        XCTAssertFalse(coordinator.isTrackingPassthrough)
    }

    @MainActor
    func testTrackerTickUpdatesOverlayOnlyWhenRectsChange() {
        let state = AppState(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        state.mode = .overlayFallback
        state.addPassthroughApp(label: "Finder", bundleIdentifier: "com.apple.finder")
        var frame = NSRect(x: 50, y: 60, width: 200, height: 120)
        let overlayController = StubOverlayFallbackController()
        let coordinator = ShadeCoordinator(
            state: state,
            overlayController: overlayController,
            passthroughWindowSnapshots: {
                [PassthroughWindowSnapshot(frame: frame, bundleIdentifier: "com.apple.finder", localizedAppName: "Finder", windowTitle: "Desktop")]
            },
            overlayDisplays: { [OverlayDisplay(frame: NSRect(x: 0, y: 0, width: 640, height: 480))] }
        )

        coordinator.setEnabled(true)
        let updatesAfterShow = overlayController.updateCallCount

        coordinator.passthroughTrackerTick() // same frame
        XCTAssertEqual(overlayController.updateCallCount, updatesAfterShow, "no change => no update")

        frame = NSRect(x: 120, y: 60, width: 200, height: 120) // window moved
        coordinator.passthroughTrackerTick()
        XCTAssertEqual(overlayController.updateCallCount, updatesAfterShow + 1, "moved window => one update")
        let clearRects = overlayController.lastAppearance?.clearRects ?? []
        XCTAssertEqual(clearRects.count, 1)
        let clearRect = clearRects[0]
        XCTAssertLessThanOrEqual(clearRect.minX, 120, "clear rect must cover window left edge")
        XCTAssertLessThanOrEqual(clearRect.minY, 60, "clear rect must cover window top edge")
        XCTAssertGreaterThanOrEqual(clearRect.maxX, 320, "clear rect must cover window right edge")
        XCTAssertGreaterThanOrEqual(clearRect.maxY, 180, "clear rect must cover window bottom edge")
    }

    @MainActor
    func testSwitchingToBlockedReadingModeStaysOnOverlayFallback() {
        let state = AppState(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        state.mode = .overlayFallback
        state.isTransformEnabled = true
        let overlayController = StubOverlayFallbackController()
        let coordinator = ShadeCoordinator(
            state: state,
            overlayController: overlayController
        )

        coordinator.setEnabled(true)
        state.mode = .readingTransform
        coordinator.modeDidChange()

        XCTAssertGreaterThanOrEqual(overlayController.hideCallCount, 1)
        XCTAssertEqual(state.mode, .overlayFallback)
        XCTAssertTrue(overlayController.isShowing)
    }

    @MainActor
    func testBlockedReadingTransformDoesNotStartCapture() {
        let state = AppState(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        state.mode = .readingTransform
        let overlayController = StubOverlayFallbackController()
        let coordinator = ShadeCoordinator(
            state: state,
            overlayController: overlayController
        )

        coordinator.setEnabled(true)

        XCTAssertEqual(state.mode, .overlayFallback)
        XCTAssertTrue(overlayController.isShowing)
    }
}

@MainActor
private final class StubOverlayFallbackController: OverlayFallbackControlling {
    private(set) var showCallCount = 0
    private(set) var hideCallCount = 0
    private(set) var updateCallCount = 0
    private(set) var lastAppearance: OverlayFallbackAppearance?
    private(set) var isShowing = false

    func show(appearance: OverlayFallbackAppearance) {
        showCallCount += 1
        lastAppearance = appearance
        isShowing = true
    }

    func hide() {
        hideCallCount += 1
        isShowing = false
    }

    func update(appearance: OverlayFallbackAppearance) {
        updateCallCount += 1
        lastAppearance = appearance
    }
}
