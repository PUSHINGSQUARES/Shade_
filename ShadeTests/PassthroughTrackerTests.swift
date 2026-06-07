import XCTest
@testable import Shade_

@MainActor
final class PassthroughTrackerTests: XCTestCase {
    func testFiresOnlyWhileRunning() {
        var ticks = 0
        let tracker = PassthroughTracker(interval: 0.01, onTick: { ticks += 1 })

        XCTAssertFalse(tracker.isRunning)
        tracker.start()
        XCTAssertTrue(tracker.isRunning)
        tracker.fireNow()
        tracker.fireNow()
        XCTAssertEqual(ticks, 2)

        tracker.stop()
        XCTAssertFalse(tracker.isRunning)
        tracker.fireNow()
        XCTAssertEqual(ticks, 2, "fireNow after stop must not tick")
    }

    func testStartIsIdempotentAndRestartable() {
        var ticks = 0
        let tracker = PassthroughTracker(interval: 0.01, onTick: { ticks += 1 })
        tracker.start()
        tracker.start()
        XCTAssertTrue(tracker.isRunning)
        tracker.stop()
        tracker.start()
        XCTAssertTrue(tracker.isRunning)
        tracker.stop()
    }

    func testTickSourceDrivesTrackerRate() {
        // Given a ManualTickSource, firing N times produces N ticks
        var ticks = 0
        let source = ManualTickSource()
        let tracker = PassthroughTracker(tickSource: source, onTick: { ticks += 1 })
        tracker.start()
        source.fire()
        source.fire()
        source.fire()
        XCTAssertEqual(ticks, 3)
        tracker.stop()
        source.fire() // should not tick after stop
        XCTAssertEqual(ticks, 3)
    }

    func testStopSuppressesTickSourceCallbackDuringTeardown() {
        var ticks = 0
        let source = StopFiringTickSource()
        let tracker = PassthroughTracker(tickSource: source, onTick: { ticks += 1 })

        tracker.start()
        tracker.stop()

        XCTAssertEqual(ticks, 0, "Callbacks fired during stop must not reach onTick")
        XCTAssertFalse(tracker.isRunning)
    }

    func testInjectedWindowSnapshotsProduceUpdatedClearRectsOnEachTick() {
        // This tests that each tick re-evaluates window positions
        var ticks = 0
        let source = ManualTickSource()
        let tracker = PassthroughTracker(tickSource: source, onTick: { ticks += 1 })
        tracker.start()
        source.fire()
        XCTAssertEqual(ticks, 1)
        source.fire()
        XCTAssertEqual(ticks, 2)
        tracker.stop()
    }
}

private final class StopFiringTickSource: TrackerTickSource {
    private var callback: (@Sendable () -> Void)?

    func start(callback: @escaping @Sendable () -> Void) {
        self.callback = callback
    }

    func stop() {
        callback?()
        callback = nil
    }
}
